import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/ecg_upload_service.dart';

class EcgNotesService {
  static String _base() => EcgUploadService.backendBaseUrl();

  // GET /api/ecg/notes/?ecg_id=123
  static Future<List<Map<String, dynamic>>> fetchNotes(int ecgId) async {
    final uri = Uri.parse('${_base()}/api/ecg/notes/?ecg_id=$ecgId');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Fetch ECG notes failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final list = (decoded as List).cast<dynamic>();
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  // POST /api/ecg/notes/   body: {ecg_id, text}
  static Future<void> addNote({required int ecgId, required String text}) async {
    final uri = Uri.parse('${_base()}/api/ecg/notes/');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ecg_id': ecgId, 'text': text}),
    );

    // accept 200 or 201
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Add ECG note failed (${res.statusCode}): ${res.body}');
    }
  }

  // PATCH /api/ecg/notes/<noteId>/   body: {text}
  static Future<void> updateNote({
    required int noteId,
    required String text,
  }) async {
    final uri = Uri.parse('${_base()}/api/ecg/notes/$noteId/');
    final res = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );

    if (res.statusCode != 200) {
      throw Exception('Update ECG note failed (${res.statusCode}): ${res.body}');
    }
  }

  // DELETE /api/ecg/notes/<noteId>/
  static Future<void> deleteNote({required int noteId}) async {
    final uri = Uri.parse('${_base()}/api/ecg/notes/$noteId/');
    final res = await http.delete(uri);

    if (res.statusCode != 200) {
      throw Exception('Delete ECG note failed (${res.statusCode}): ${res.body}');
    }
  }
}