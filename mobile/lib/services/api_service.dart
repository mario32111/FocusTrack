import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final String baseUrl = 'http://192.168.1.72:3000';
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Error ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('ApiService GET error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getList(String path) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      throw Exception('Error ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('ApiService GET_LIST error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Error ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('ApiService POST error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Error ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('ApiService PUT error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Error ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('ApiService DELETE error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> postExternal(String url, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Error ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('ApiService POST_EXTERNAL error: $e');
      rethrow;
    }
  }
}
