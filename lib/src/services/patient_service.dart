// lib/src/services/patient_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/patient.dart';
import 'ecg_upload_service.dart';

class PatientService {
  /// Login with patient_id, or create new if not exists.
  /// Backend rule:
  /// - If ID exists and name does not match => 409 with {"error": "..."}
  static Future<Patient> loginOrCreate({
    required String patientId,
    required String name,
  }) async {
    final uri = Uri.parse(
      '${EcgUploadService.backendBaseUrl()}/api/patient/login_or_create/',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patient_id': patientId,
        'name': name,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Patient.fromJson(data);
    }

    final message = _extractMessage(response.body, fallback: 'Login failed.');

    if (response.statusCode == 409) {
      throw Exception(message);
    }

    throw Exception('Server error (${response.statusCode}): $message');
  }

  /// Fetch all patients for dashboard browsing
  static Future<List<Map<String, dynamic>>> fetchPatientsRaw() async {
    final uri =
    Uri.parse('${EcgUploadService.backendBaseUrl()}/api/patients/');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch patients (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (decoded['patients'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    return list;
  }

  /// ✅ Create patient (ID unique, age required, gender optional)
  static Future<Map<String, dynamic>> createPatient({
    required String patientId,
    required String fullName,
    required int age, // ✅ NEW (REQUIRED)
    String? gender, // "M" or "F" or null
  }) async {
    final uri =
    Uri.parse('${EcgUploadService.backendBaseUrl()}/api/patients/');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patient_id': patientId,
        'full_name': fullName,
        'age': age, // ✅ NEW
        'gender': gender, // may be null
      }),
    );

    if (response.statusCode == 201) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['patient'] as Map<String, dynamic>;
    }

    final message =
    _extractMessage(response.body, fallback: 'Create patient failed.');

    if (response.statusCode == 409) {
      throw Exception(message); // patient_id already exists
    }

    throw Exception('Server error (${response.statusCode}): $message');
  }

  /// Delete patient
  static Future<void> deletePatient(String patientId) async {
    // Pattern 1: DELETE /api/patients/<id>/
    final uri1 = Uri.parse(
      '${EcgUploadService.backendBaseUrl()}/api/patients/$patientId/',
    );
    final r1 = await http.delete(uri1);

    if (r1.statusCode == 200 || r1.statusCode == 204) return;

    // Pattern 2: POST /api/patients/delete/
    final uri2 = Uri.parse(
      '${EcgUploadService.backendBaseUrl()}/api/patients/delete/',
    );
    final r2 = await http.post(
      uri2,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'patient_id': patientId}),
    );

    if (r2.statusCode == 200 || r2.statusCode == 204) return;

    final msg =
    _extractMessage(r2.body, fallback: 'Delete patient failed.');
    throw Exception('Server error (${r2.statusCode}): $msg');
  }

  static String _extractMessage(String body,
      {required String fallback}) {
    if (body.trim().isEmpty) return fallback;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return (decoded['error'] ??
            decoded['message'] ??
            fallback)
            .toString();
      }
      return decoded.toString();
    } catch (_) {
      return body;
    }
  }
}