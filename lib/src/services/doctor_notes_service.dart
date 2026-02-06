// lib/src/services/doctor_notes_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'ecg_upload_service.dart';

class DoctorNotesService {
  static String _base() => EcgUploadService.backendBaseUrl();

  static Uri _notesUri(String patientId) {
    // IMPORTANT: full URL with host
    return Uri.parse('${_base()}/api/patients/$patientId/notes/');
  }

  static Uri _noteDetailUri(String patientId, int noteId) {
    return Uri.parse('${_base()}/api/patients/$patientId/notes/$noteId/');
  }

  /// GET /api/patients/<patientId>/notes/
  static Future<List<Map<String, dynamic>>> fetchNotes(String patientId) async {
    final res = await http.get(_notesUri(patientId));

    if (res.statusCode != 200) {
      throw Exception('Failed to load notes (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    // Expected: {"notes":[...]}
    if (decoded is Map<String, dynamic>) {
      final list = (decoded['notes'] as List<dynamic>? ?? []);
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }

    // Fallback: if backend returns list directly
    if (decoded is List) {
      return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }

    return [];
  }

  /// POST /api/patients/<patientId>/notes/  body: {"text":"..."}
  static Future<Map<String, dynamic>> addNote({
    required String patientId,
    required String text,
  }) async {
    final res = await http.post(
      _notesUri(patientId),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );

    if (res.statusCode != 201) {
      throw Exception('Failed to save note (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;

    // Expected: {"note": {...}}
    if (decoded['note'] is Map) {
      return (decoded['note'] as Map).cast<String, dynamic>();
    }
    return decoded;
  }

  /// PATCH /api/patients/<patientId>/notes/<noteId>/  body: {"text":"..."}
  static Future<Map<String, dynamic>> updateNote({
    required String patientId,
    required int noteId,
    required String text,
  }) async {
    final res = await http.patch(
      _noteDetailUri(patientId, noteId),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to update note (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (decoded['note'] is Map) {
      return (decoded['note'] as Map).cast<String, dynamic>();
    }
    return decoded;
  }

  /// DELETE /api/patients/<patientId>/notes/<noteId>/
  static Future<void> deleteNote({
    required String patientId,
    required int noteId,
  }) async {
    final res = await http.delete(_noteDetailUri(patientId, noteId));

    if (res.statusCode != 200) {
      throw Exception('Failed to delete note (${res.statusCode}): ${res.body}');
    }
  }
}