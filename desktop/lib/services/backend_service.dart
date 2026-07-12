import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendService {
  Process? _process;
  String _listenHost = 'localhost';
  int _listenPort = 0;
  String get baseUrl => 'http://$_listenHost:$_listenPort';
  String get listenAddress => '$_listenHost:$_listenPort';

  static Future<int> findRandomPort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }

  Future<bool> isRunning() async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/'));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> start({String? listenAddr, String? storePath}) async {
    if (listenAddr != null && listenAddr.isNotEmpty) {
      _listenHost = 'localhost';
      _listenPort = int.tryParse(listenAddr.replaceAll(':', '')) ?? 0;
      if (_listenPort == 0) {
        _listenPort = await findRandomPort();
      }
    } else {
      _listenHost = 'localhost';
      _listenPort = await findRandomPort();
    }

    if (await isRunning()) return;

    final dir = _findBackendDir();
    final exe = Platform.isWindows ? 'network-prober.exe' : 'network-prober';
    final backend = File('${dir.path}/$exe');

    if (!backend.existsSync()) {
      throw Exception('Backend binary not found at: ${backend.path}');
    }

    final args = ['-listen', '$_listenHost:$_listenPort', '-log-level', 'warn'];
    if (storePath != null && storePath.isNotEmpty) {
      args.addAll(['-store', storePath]);
    }

    _process = await Process.start(
      backend.path,
      args,
      workingDirectory: dir.path,
    );

    _process!.stdout.transform(utf8.decoder).listen(
      (line) => print('[backend] $line'),
    );
    _process!.stderr.transform(utf8.decoder).listen(
      (line) => print('[backend:err] $line'),
    );

    for (int i = 0; i < 30; i++) {
      if (await isRunning()) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    throw Exception('Backend failed to start within 15s');
  }

  void stop() {
    _process?.kill();
    _process = null;
  }

  Directory _findBackendDir() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final suffix = Platform.isWindows ? '.exe' : '';
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