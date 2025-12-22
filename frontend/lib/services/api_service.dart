import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Automatically use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load health status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }

  static Future<List<dynamic>> getLibraries() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/libraries'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['items'];
      } else {
        throw Exception('Failed to load libraries: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching libraries: $e');
    }
  }

  static Future<Map<String, dynamic>> getLibraryDetails(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/libraries/$id'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['library'];
      } else {
        throw Exception(
          'Failed to load library details: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching library details: $e');
    }
  }
}
