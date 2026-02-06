import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/patient.dart';
import 'ecg_upload_service.dart';

class PatientService {
  static Future<Patient> loginOrCreate({
    required String patientId,
    required String name,
  }) async {
    final uri = Uri.parse('${EcgUploadService.backendBaseUrl()}/api/patient/login_or_create/');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'patient_id': patientId, 'name': name}),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return Patient.fromJson(data);
    }

    final msg = _extractMessage(res.body, fallback: 'Login failed.');
    if (res.statusCode == 409) throw Exception(msg);

    throw Exception('Server error (${res.statusCode}): $msg');
  }

  static Future<List<Map<String, dynamic>>> fetchPatientsRaw() async {
    final uri = Uri.parse('${EcgUploadService.backendBaseUrl()}/api/patients/');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch patients (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (decoded['patients'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    return list;
  }

  static Future<Map<String, dynamic>> createPatient({
    required String patientId,
    required String fullName,
    required int age,
    String? gender, // "M" or "F"
  }) async {
    final uri = Uri.parse('${EcgUploadService.backendBaseUrl()}/api/patients/');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patient_id': patientId,
        'full_name': fullName,
        'age': age,
        'gender': gender,
      }),
    );

    if (res.statusCode == 201) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return decoded['patient'] as Map<String, dynamic>;
    }

    final msg = _extractMessage(res.body, fallback: 'Create patient failed.');
    if (res.statusCode == 409) throw Exception(msg);

    throw Exception('Server error (${res.statusCode}): $msg');
  }

  static Future<void> deletePatient(String patientId) async {
    // Pattern: POST /api/patients/delete/
    final uri = Uri.parse('${EcgUploadService.backendBaseUrl()}/api/patients/delete/');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'patient_id': patientId}),
    );

    if (res.statusCode == 200 || res.statusCode == 204) return;

    final msg = _extractMessage(res.body, fallback: 'Delete patient failed.');
    throw Exception('Server error (${res.statusCode}): $msg');
  }

  static String _extractMessage(String body, {required String fallback}) {
    if (body.trim().isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return (decoded['error'] ?? decoded['message'] ?? fallback).toString();
      }
      return decoded.toString();
    } catch (_) {
      return body;
    }
  }
}