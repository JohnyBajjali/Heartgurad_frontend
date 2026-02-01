import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class EcgUploadService {
  /// Public so other services can reuse the same base URL.
  static String backendBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static String _inferImageExtToSubtype(String name) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'jpeg';
      case '.png':
        return 'png';
      case '.webp':
        return 'webp';
      default:
        return 'jpeg';
    }
  }

  static MediaType _signalMediaType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    if (ext == '.xml') return MediaType('application', 'xml');

    // aECG isn't standardized everywhere; safest is octet-stream.
    return MediaType('application', 'octet-stream');
  }

  /// Upload ECG IMAGE (JPG/PNG/WEBP) to Django backend
  static Future<http.StreamedResponse> uploadEcg({
    required Uint8List imageBytes,
    required String fileName,
    required String patientName,
    required String patientId,
  }) async {
    final uri = Uri.parse('${backendBaseUrl()}/api/ecg/upload/');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
        contentType: MediaType('image', _inferImageExtToSubtype(fileName)),
      ),
    );

    request.fields['source'] = 'mobile';
    request.fields['patient_name'] = patientName;
    request.fields['patient_id'] = patientId;

    return request.send();
  }

  /// Auto-crop IMAGE via backend OpenCV
  static Future<Uint8List> autoCropEcg({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('${backendBaseUrl()}/api/ecg/auto_crop/');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
        contentType: MediaType('image', _inferImageExtToSubtype(fileName)),
      ),
    );

    final streamed = await request.send();
    final respBytes = await streamed.stream.toBytes();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final msg = String.fromCharCodes(respBytes);
      throw Exception('auto_crop failed (${streamed.statusCode}): $msg');
    }

    return Uint8List.fromList(respBytes);
  }

  /// Upload SIGNAL file (XML/aECG) to backend (for analyzer model)
  ///
  /// ✅ Your Django backend already supports BOTH formats using:
  ///    POST /api/ecg/predict/
  /// It detects format automatically (Philips XML vs HL7 aECG).
  static Future<http.StreamedResponse> uploadSignal({
    required Uint8List fileBytes,
    required String fileName,
    required String patientName,
    required String patientId,
  }) async {
    // ✅ unified endpoint in your backend: HeartGuardBE/views.py -> predict_ecg
    final uri = Uri.parse('${backendBaseUrl()}/api/ecg/predict/');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: _signalMediaType(fileName),
      ),
    );

    request.fields['patient_name'] = patientName;
    request.fields['patient_id'] = patientId;

    return request.send();
  }
}