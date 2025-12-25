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

  static Future<Map<String, dynamic>> getFacilityTimeSlots(
    int facilityId,
    String date,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/v1/facilities/$facilityId/timeslots?date=$date',
        ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load time slots: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching time slots: $e');
    }
  }

  // static Future<void> createReservation({
  //   required int facilityId,
  //   required String date,
  //   required String startTime,
  //   required String endTime,
  //   required String userName,
  //   required String userEmail,
  // }) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/api/v1/reservations'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: json.encode({
  //         'facility_id': facilityId,
  //         'reservation_date': date,
  //         'start_time': startTime,
  //         'end_time': endTime,
  //         'user_full_name': userName,
  //         'user_email': userEmail,
  //         'notes': 'Mobile App Booking',
  //       }),
  //     );

  //     if (response.statusCode != 201) {
  //       final error = json.decode(response.body);
  //       throw Exception(error['detail'] ?? 'Failed to create reservation');
  //     }
  //   } catch (e) {
  //     throw Exception('Error creating reservation: $e');
  //   }
  // }
}
