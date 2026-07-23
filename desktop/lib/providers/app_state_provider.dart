import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/module.dart';
import '../models/probe_item.dart';
import '../models/probe_result.dart';
import '../models/api_requests.dart';
import '../services/api_service.dart';
import '../services/backend_service.dart';

final appStateProvider = ChangeNotifierProvider<AppState>((ref) {
  return AppState();
});

class AppState extends ChangeNotifier {
  final ApiService _api = ApiService();
  final BackendService _backend = BackendService();

  int _backendPort = 18081;
  String get backendPort => _backendPort.toString();
  String _backendAddress = '';
  String get backendAddress => _backendAddress;

  String _storePath = '';
  String get storePath => _storePath;

  List<Module> _modules = [];
  List<Module> get modules => _modules;

  List<ProbeItem> _items = [];
  List<ProbeItem> get items => _items;

  final Map<int, List<ProbeResult>> _results = {};
  Map<int, List<ProbeResult>> get results => _results;

  int? _selectedModuleId;
  int? get selectedModuleId => _selectedModuleId;
  set selectedModuleId(int? id) {
    _selectedModuleId = id;
    notifyListeners();
  }

  bool _loading = false;
  bool get loading => _loading;

  bool _backendReady = false;
  bool get backendReady => _backendReady;

  bool _backendReachable = false;
  bool get backendReachable => _backendReachable;

  String? _error;
  String? get error => _error;

  AppState() {
    final config = BackendService.loadConfig();
    _backendPort = config.port;
    _storePath = config.store;
    _backendAddress = 'localhost:${config.port}';
  }

  Future<void> initBackend() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _backend.start();
      _backendAddress = _backend.listenAddress;
      _api.updateBaseUrl(_backend.baseUrl);
      _backendReady = true;
      _backendReachable = true;
      await loadData();
    } catch (e) {
      _error = '启动后端失败: $e';
      _backendReady = false;
      _backendReachable = false;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> checkBackendHealth() async {
    if (!_backendReachable && !_backendReady) return;
    final ok = await _backend.isRunningOnPort(_backendPort);
    if (ok && !_backendReady) {
      _backendReady = true;
      _api.updateBaseUrl('http://localhost:$_backendPort');
      await loadData();
      notifyListeners();
    } else if (!ok && _backendReady) {
      _backendReady = false;
      _backendReachable = true;
      notifyListeners();
    }
  }

  Future<void> restartSystemdService() async {
    _loading = true;
    _backendReady = false;
    _backendReachable = false;
    _error = null;
    notifyListeners();
    try {
      final ok = await _backend.restartSystemdService();
      if (ok) {
        for (int i = 0; i < 30; i++) {
          if (await _backend.isRunningOnPort(_backendPort)) {
            _backendAddress = 'localhost:$_backendPort';
            _api.updateBaseUrl(_backend.baseUrl);
            _backendReady = true;
            _backendReachable = true;
            await loadData();
            _loading = false;
            notifyListeners();
            return;
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }
        _error = '后端重启后未能在15s内响应';
      } else {
        _error = '重启失败：pkexec被取消或无权限';
      }
    } catch (e) {
      _error = '重启失败: $e';
    }
    _loading = false;
    if (!_backendReady) _backendReachable = _backendReachable;
    notifyListeners();
  }

  Future<void> loadData() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await Future.wait([
        _api.getModules(),
        _api.getItems(),
      ]);
      _modules = r[0] as List<Module>;
      _items = r[1] as List<ProbeItem>;
      _backendReady = true;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> saveConfig() async {
    final config = BackendConfig(
      listen: '$_backendPort',
      store: _storePath,
    );
    return await BackendService.saveConfig(config);
  }

  Future<void> updateBackendPort(String portStr) async {
    final port = int.tryParse(portStr.trim());
    if (port != null && port > 0 && port < 65536) {
      _backendPort = port;
    } else {
      _backendPort = 18081;
    }
    _backendAddress = 'localhost:$_backendPort';
    notifyListeners();
  }

  void setStorePath(String path) {
    _storePath = path;
    notifyListeners();
  }

  Future<void> addModule(String name, {int parentId = 0}) async {
    try {
      await _api.createModule(CreateModuleRequest(name: name, parentId: parentId));
      await loadData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> renameModule(int id, String name) async {
    try {
      await _api.updateModule(id, UpdateModuleRequest(name: name));
      await loadData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeModule(int id) async {
    try {
      await _api.deleteModule(id);
      await loadData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> moveModule(int id, {int newParentId = 0, int sortOrder = 0}) async {
    try {
      await _api.moveModule(MoveModuleRequest(id: id, newParentId: newParentId, sortOrder: sortOrder));
      await loadData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addItem(String address, String protocol, String probeType, int moduleId, {String? certData}) async {
    try {
      await _api.createItem(CreateItemRequest(address: address, protocol: protocol, probeType: probeType, moduleId: moduleId, certData: certData));
      await loadData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateItem(int id, UpdateItemRequest req) async {
    try {
      await _api.updateItem(id, req);
      await loadData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeItem(int id) async {
    try {
      await _api.deleteItem(id);
      await loadData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> moveItem(int id, {int newModuleId = 0, int sortOrder = 0}) async {
    try {
      await _api.moveItem(MoveItemRequest(id: id, newModuleId: newModuleId, sortOrder: sortOrder));
      await loadData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> importItems(int moduleId, List<ImportItem> items, {String protocol = 'http', String probeType = 'full'}) async {
    try {
      await _api.importItems(ImportRequest(moduleId: moduleId, protocol: protocol, probeType: probeType, items: items));
      await loadData();
      _selectedModuleId = moduleId;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> detectItems(List<int> itemIds) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _api.detect(DetectRequest(itemIds: itemIds));
      for (final result in r) {
        _results[result.itemId] = [result];
      }
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> exportModule(int id) async {
    try {
      return await _api.exportModule(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> importModule(Map<String, dynamic> data) async {
    try {
      await _api.importModule(data);
      await loadData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<ProbeItem> getItem(int id) async {
    return await _api.getItem(id);
  }

  List<ProbeItem> getItemsForModule(int moduleId) {
    return _items.where((item) => item.moduleId == moduleId).toList();
  }

  List<Module> getChildModules(int parentId) {
    return _modules.where((m) => m.parentId == parentId).toList();
  }

  int getResultStatus(int itemId) {
    final itemResults = _results[itemId];
    if (itemResults == null || itemResults.isEmpty) return -1;
    final r = itemResults.first;
    if (r.successCount == r.totalTargets && r.totalTargets > 0) return 2;
    if (r.successCount > 0) return 1;
    return 0;
  }

  // -- Item selection --
  final Set<int> _selectedItemIds = {};
  Set<int> get selectedItemIds => Set.unmodifiable(_selectedItemIds);

  bool isItemSelected(int itemId) => _selectedItemIds.contains(itemId);

  void toggleItemSelection(int itemId) {
    if (_selectedItemIds.contains(itemId)) {
      _selectedItemIds.remove(itemId);
    } else {
      _selectedItemIds.add(itemId);
    }
    notifyListeners();
  }

  void selectAllItems() {
    final ids = getItemsForModule(_selectedModuleId ?? -1).map((e) => e.id);
    _selectedItemIds.addAll(ids);
    notifyListeners();
  }

  void deselectAllItems() {
    _selectedItemIds.clear();
    notifyListeners();
  }

  void toggleSelectAll() {
    final ids = getItemsForModule(_selectedModuleId ?? -1).map((e) => e.id).toSet();
    if (_selectedItemIds.containsAll(ids)) {
      deselectAllItems();
    } else {
      selectAllItems();
    }
  }

  void clearResults() {
    _results.clear();
    notifyListeners();
  }
}
