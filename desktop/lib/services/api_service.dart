import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/module.dart';
import '../models/probe_item.dart';
import '../models/probe_result.dart';
import '../models/api_requests.dart';

class ApiService {
  String baseUrl;
  late http.Client _client;

  static final ApiService _instance = ApiService._internal(
    baseUrl: 'http://localhost:18081',
  );

  factory ApiService({String? baseUrl}) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      return ApiService._internal(baseUrl: baseUrl);
    }
    return _instance;
  }

  ApiService._internal({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? 'http://localhost:18081' {
    _client = client ?? http.Client();
  }

  void updateBaseUrl(String url) {
    baseUrl = url;
    _client.close();
    _client = http.Client();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    }
    throw Exception(response.body);
  }

  Future<List<Module>> getModules() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/modules'),
      headers: _headers,
    );
    final data = await _handleResponse(response) as List<dynamic>;
    return data.map((e) => Module.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Module> createModule(CreateModuleRequest req) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/modules'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    final data = await _handleResponse(response) as Map<String, dynamic>;
    return Module.fromJson(data);
  }

  Future<Module> updateModule(int id, UpdateModuleRequest req) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/api/modules/$id'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    final data = await _handleResponse(response) as Map<String, dynamic>;
    return Module.fromJson(data);
  }

  Future<void> deleteModule(int id) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/modules/$id'),
      headers: _headers,
    );
    await _handleResponse(response);
  }

  Future<Module> moveModule(MoveModuleRequest req) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/modules/move'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    final data = await _handleResponse(response) as Map<String, dynamic>;
    return Module.fromJson(data);
  }

  Future<List<ProbeItem>> getItems() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/items'),
      headers: _headers,
    );
    final data = await _handleResponse(response) as List<dynamic>;
    return data.map((e) => ProbeItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ProbeItem> createItem(CreateItemRequest req) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/items'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    final data = await _handleResponse(response) as Map<String, dynamic>;
    return ProbeItem.fromJson(data);
  }

  Future<ProbeItem> updateItem(int id, UpdateItemRequest req) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/api/items/$id'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    final data = await _handleResponse(response) as Map<String, dynamic>;
    return ProbeItem.fromJson(data);
  }

  Future<void> deleteItem(int id) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/items/$id'),
      headers: _headers,
    );
    await _handleResponse(response);
  }

  Future<void> importItems(ImportRequest req) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/items/import'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    await _handleResponse(response);
  }

  Future<void> moveItem(MoveItemRequest req) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/items/move'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    await _handleResponse(response);
  }

  Future<List<ProbeResult>> detect(DetectRequest req) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/detect'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    final data = await _handleResponse(response) as List<dynamic>;
    return data.map((e) => ProbeResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ProbeItem> getItem(int id) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/items/$id'),
      headers: _headers,
    );
    final data = await _handleResponse(response) as Map<String, dynamic>;
    return ProbeItem.fromJson(data);
  }
}
