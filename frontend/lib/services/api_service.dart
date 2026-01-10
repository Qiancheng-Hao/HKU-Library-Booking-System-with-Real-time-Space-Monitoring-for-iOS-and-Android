import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();

  // Automatically use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    // return 'http://127.0.0.1:8000';
    // For physical iOS device, use your Mac's local IP
    // return 'http://172.20.10.4:8000';
    return 'http://192.168.0.202:8000';
    // ipconfig getifaddr en0
    // uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
  }

  // --- Auth ---

  static Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _storage.write(key: 'auth_token', value: data['access_token']);
        await _storage.write(key: 'user_email', value: email);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Error logging in: $e');
    }
  }

  static Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Error registering: $e');
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_email');
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<String?> getUserEmail() async {
    return await _storage.read(key: 'user_email');
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/auth/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        _handleAuthError();
        return {};
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static void _handleAuthError() {
    if (navigatorKey.currentContext != null) {
      final context = navigatorKey.currentContext!;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.logout();

      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // --- Public Endpoints ---

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
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/libraries'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['items'];
      } else if (response.statusCode == 401) {
        _handleAuthError();
        return [];
      } else {
        throw Exception('Failed to load libraries: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching libraries: $e');
    }
  }

  static Future<Map<String, dynamic>> getLibraryDetails(int id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/libraries/$id'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['library'];
      } else if (response.statusCode == 401) {
        _handleAuthError();
        return {};
      } else {
        throw Exception(
          'Failed to load library details: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching library details: $e');
    }
  }

  static Future<Map<String, dynamic>> getFacilityTimeSlots(
    int facilityId,
    String date,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/v1/facilities/$facilityId/timeslots?date=$date',
        ),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        _handleAuthError();
        return {};
      } else {
        throw Exception('Failed to load time slots: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching time slots: $e');
    }
  }

  static Future<void> createReservation({
    required int facilityId,
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/reservations'),
      headers: headers,
      body: json.encode({
        'facility_id': facilityId,
        'reservation_date': date,
        'start_time': startTime,
        'end_time': endTime,
        'notes': 'Mobile App Booking',
      }),
    );

    if (response.statusCode != 201) {
      if (response.statusCode == 401) {
        _handleAuthError();
        return;
      }
      final error = json.decode(response.body);
      throw error['detail'] ?? 'Failed to create reservation';
    }
  }

  static Future<List<dynamic>> getUserReservations() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/reservations/my'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['items'];
      } else if (response.statusCode == 401) {
        _handleAuthError();
        return [];
      } else {
        throw Exception('Failed to load reservations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching reservations: $e');
    }
  }

  static Future<void> cancelReservation(String reservationId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/reservations/$reservationId'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        if (response.statusCode == 401) {
          _handleAuthError();
          return;
        }
        throw Exception('Failed to cancel reservation: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error cancelling reservation: $e');
    }
  }

  // --- Occupancy ---

  static Future<Map<String, dynamic>> getRealtimeOccupancy({
    double? latitude,
    double? longitude,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      // Default to HKU coordinates if not provided
      final double lat = latitude ?? 22.2830;
      final double lon = longitude ?? 114.1371;

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/occupancy/occupancy'),
        headers: headers,
        body: json.encode({
          'latitude': lat,
          'longitude': lon,
          'radius': 50000000,
          'maxResults': 20,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        _handleAuthError();
        return {};
      } else {
        throw Exception(
          'Failed to load occupancy data: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching occupancy data: $e');
    }
  }

  static Future<Map<String, dynamic>> getOccupancyRecommendation({
    double? latitude,
    double? longitude,
    String strategy = 'distance', // 'distance' or 'occupancyRate'
  }) async {
    try {
      final headers = await _getAuthHeaders();
      // Default to HKU coordinates if not provided
      final double lat = latitude ?? 22.2830;
      final double lon = longitude ?? 114.1371;

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/occupancy/recommendation'),
        headers: headers,
        body: json.encode({
          'latitude': lat,
          'longitude': lon,
          'strategy': strategy,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        _handleAuthError();
        return {};
      } else if (response.statusCode == 404) {
        return {};
      } else {
        throw Exception(
          'Failed to load recommendation: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching recommendation: $e');
    }
  }
}
