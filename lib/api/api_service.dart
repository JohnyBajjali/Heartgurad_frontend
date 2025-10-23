// lib/api/api_service.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_constants.dart';
import '../models/patient.dart';
import '../models/ecg_exam.dart';

class ApiService {
  ApiService._internal();
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  final _storage = const FlutterSecureStorage();

  Uri _url(String path) => Uri.parse('${ApiConstants.baseUrl}$path');

  Future<String?> _readAccess() async => _storage.read(key: 'auth_token');
  Future<String?> _readRefresh() async => _storage.read(key: 'refresh_token');

  Future<Map<String, String>> _baseHeaders({bool withAuth = true}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (withAuth) {
      final token = await _readAccess();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<http.Response> _authGet(String path) async {
    var res = await http.get(_url(path), headers: await _baseHeaders());
    if (res.statusCode == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        res = await http.get(_url(path), headers: await _baseHeaders());
      }
    }
    return res;
  }

  Future<bool> _refreshAccessToken() async {
    final refresh = await _readRefresh();
    if (refresh == null || refresh.isEmpty) return false;

    final res = await http.post(
      _url('/api/token/refresh/'),
      headers: await _baseHeaders(withAuth: false),
      body: json.encode({'refresh': refresh}),
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      final newAccess = (data['access'] ?? '').toString();
      if (newAccess.isNotEmpty) {
        await _storage.write(key: 'auth_token', value: newAccess);
        return true;
      }
    }
    return false;
  }

  // ───────────────────── Patients ─────────────────────

  Future<List<Patient>> getPatients() async {
    final res = await _authGet('/api/patients/');

    if (res.statusCode == 200) {
      final decoded = json.decode(res.body);
      List<dynamic> items;
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['results'] is List) {
        items = decoded['results'] as List<dynamic>;
      } else {
        throw Exception('Unexpected patients payload.');
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map((e) => Patient.fromJson(e))
          .toList();
    } else if (res.statusCode == 401) {
      throw Exception('Unauthorized (401). Please sign in again.');
    } else {
      throw Exception('Failed to load patients. Status code: ${res.statusCode}');
    }
  }

  Future<Patient> getPatientById(int id) async {
    final res = await _authGet('/api/patients/$id/');

    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return Patient.fromJson(data);
    } else if (res.statusCode == 404) {
      throw Exception('Patient not found.');
    } else if (res.statusCode == 401) {
      throw Exception('Unauthorized (401). Please sign in again.');
    } else {
      throw Exception('Failed to load patient details. Status code: ${res.statusCode}');
    }
  }

  // ───────────────────── ECG Exams ─────────────────────

  /// GET /api/ecg-exams/?status=READY (status optional)
  Future<List<EcgExam>> getEcgExams({String? status}) async {
    final q = status != null && status.isNotEmpty ? '?status=$status' : '';
    final res = await _authGet('/api/ecg-exams/$q');

    if (res.statusCode == 200) {
      final decoded = json.decode(res.body);
      List<dynamic> items;
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['results'] is List) {
        items = decoded['results'] as List<dynamic>;
      } else {
        throw Exception('Unexpected ECG exams payload.');
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map((e) => EcgExam.fromJson(e))
          .toList();
    } else {
      throw Exception('Failed to load ECG exams (HTTP ${res.statusCode}).');
    }
  }

  /// GET /api/ecg-exams/{id}/
  Future<EcgExam> getEcgExamById(int id) async {
    final res = await _authGet('/api/ecg-exams/$id/');
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return EcgExam.fromJson(data);
    } else if (res.statusCode == 404) {
      throw Exception('ECG exam not found.');
    } else {
      throw Exception('Failed to load ECG exam (HTTP ${res.statusCode}).');
    }
  }
}
