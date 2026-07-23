import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendConfig {
  final String listen;
  final String store;
  final String logLevel;

  BackendConfig({
    this.listen = ':18081',
    this.store = 'data/store.json',
    this.logLevel = 'warn',
  });

  int get port {
    final p = listen.split(':').last;
    return int.tryParse(p) ?? 18081;
  }

  Map<String, dynamic> toJson() => {
    'listen': listen,
    'store': store,
    'log_level': logLevel,
  };

  factory BackendConfig.fromJson(Map<String, dynamic> json) {
    return BackendConfig(
      listen: (json['listen'] as String?) ?? ':18081',
      store: (json['store'] as String?) ?? 'data/store.json',
      logLevel: (json['log_level'] as String?) ?? 'warn',
    );
  }
}

class BackendService {
  String _listenHost = 'localhost';
  int _listenPort = 0;

  String get baseUrl => 'http://$_listenHost:$_listenPort';
  String get listenAddress => '$_listenHost:$_listenPort';

  static final List<String> _systemdServicePaths = [
    '/lib/systemd/system/network-prober.service',
    '/etc/systemd/system/network-prober.service',
  ];

  static String get _systemdConfigPath => '/etc/network-prober/config.json';

  static String get _userConfigPath {
    final xdgConfig = Platform.environment['XDG_CONFIG_HOME'] ??
        '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.'}/.config';
    return '$xdgConfig/network-prober/config.json';
  }

  static List<String> get _configPaths => [_systemdConfigPath, _userConfigPath];

  static BackendConfig loadConfig() {
    for (final p in _configPaths) {
      try {
        final file = File(p);
        if (file.existsSync()) {
          final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          return BackendConfig.fromJson(data);
        }
      } catch (_) {}
    }
    return BackendConfig();
  }

  static Future<bool> saveConfig(BackendConfig config) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(config.toJson());

    // Systemd mode: write via pkexec
    if (await _isSystemdActive()) {
      try {
        final proc = await Process.start('pkexec', [
          'sh', '-c',
          'mkdir -p /etc/network-prober && cat > $_systemdConfigPath',
        ]);
        proc.stdin.write(jsonStr);
        await proc.stdin.close();
        final r = await proc.exitCode;
        if (r == 0) return true;
        return false;
      } catch (_) {
        return false;
      }
    }

    // Portable/other: write directly to user config
    try {
      final dir = Directory(_userConfigPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File(_userConfigPath).writeAsStringSync(jsonStr);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isSystemdActive() async {
    if (!Platform.isLinux) return false;
    for (final p in _systemdServicePaths) {
      if (!File(p).existsSync()) continue;
      try {
        final r = await Process.run('systemctl', ['is-active', 'network-prober.service']);
        return r.exitCode == 0 && (r.stdout as String).trim() == 'active';
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static Future<bool> isSystemdActive() => _isSystemdActive();

  static int? _detectPortFromSystemdService() {
    for (final p in _systemdServicePaths) {
      try {
        final file = File(p);
        if (!file.existsSync()) continue;
        final content = file.readAsStringSync();
        final match = RegExp(r'-listen\s+:(\d+)').firstMatch(content);
        if (match != null) return int.parse(match.group(1)!);

        final confMatch = RegExp(r'-conf\s+(\S+)').firstMatch(content);
        if (confMatch != null) {
          final confFile = File(confMatch.group(1)!);
          if (confFile.existsSync()) {
            final confData = jsonDecode(confFile.readAsStringSync()) as Map<String, dynamic>;
            return BackendConfig.fromJson(confData).port;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool> isRunningOnPort(int port) async {
    try {
      final r = await http.get(Uri.parse('http://localhost:$port/'));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> start() async {
    final config = loadConfig();
    _listenHost = 'localhost';
    _listenPort = config.port;

    if (await isRunningOnPort(_listenPort)) return;

    if (await _isSystemdActive()) {
      final detected = _detectPortFromSystemdService();
      if (detected != null && detected != _listenPort) {
        _listenPort = detected;
        if (await isRunningOnPort(_listenPort)) return;
      }
      return;
    }

    final dir = _findBackendDir();
    final exe = Platform.isWindows ? 'network-prober.exe' : 'network-prober';
    final backend = File('${dir.path}/$exe');

    if (!backend.existsSync()) {
      throw Exception('Backend binary not found at: ${backend.path}');
    }

    final args = ['-conf', configFileForDir(dir)];

    try {
      await Process.start(backend.path, args, workingDirectory: dir.path);
    } catch (_) {}

    for (int i = 0; i < 30; i++) {
      if (await isRunningOnPort(_listenPort)) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    throw Exception('Backend failed to start within 15s');
  }

  static String configFileForDir(Directory dir) {
    final p = '${dir.path}/config.json';
    if (!File(p).existsSync()) {
      File(p).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(BackendConfig().toJson()),
      );
    }
    return p;
  }

  Future<bool> restartSystemdService() async {
    if (!Platform.isLinux) return false;
    try {
      final r = await Process.run('pkexec', ['systemctl', 'restart', 'network-prober']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Directory _findBackendDir() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final suffix = Platform.isWindows ? '.exe' : '';

    final backendDir = Directory('${exeDir.path}/backend');
    if (File('${backendDir.path}/network-prober$suffix').existsSync()) {
      return backendDir;
    }

    for (var dir = exeDir; dir.path != dir.parent.path; dir = dir.parent) {
      if (File('${dir.path}/network-prober$suffix').existsSync()) {
        return dir;
      }
    }
    if (File('${Directory.current.path}/network-prober$suffix').existsSync()) {
      return Directory.current;
    }
    return exeDir;
  }
}
