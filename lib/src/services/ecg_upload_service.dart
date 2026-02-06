import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class EcgUploadService {
  static String backendBaseUrl() {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static String _inferImageSubtype(String name) {
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

  static bool _isImage(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    return ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp';
  }

  static MediaType _signalMediaType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    if (ext == '.xml') return MediaType('application', 'xml');
    return MediaType('application', 'octet-stream'); // aECG safest
  }

  static Future<String> _readStreamedBody(http.StreamedResponse r) async {
    return await r.stream.bytesToString();
  }

  /// ------------------------------
  /// Upload any ECG file (image or signal) and get JSON containing ecg_id
  /// POST /api/ecg/upload/
  /// ------------------------------
  static Future<Map<String, dynamic>> uploadEcgAndGetJson({
    required Uint8List fileBytes,
    required String fileName,
    required String patientName,
    required String patientId,
  }) async {
    final uri = Uri.parse('${backendBaseUrl()}/api/ecg/upload/');
    final req = http.MultipartRequest('POST', uri);

    final isImg = _isImage(fileName);
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: isImg
            ? MediaType('image', _inferImageSubtype(fileName))
            : _signalMediaType(fileName),
      ),
    );

    req.fields['source'] = 'mobile';
    req.fields['patient_name'] = patientName;
    req.fields['patient_id'] = patientId;

    final streamed = await req.send();
    final body = await _readStreamedBody(streamed);

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Upload failed (${streamed.statusCode}): $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Upload returned unexpected JSON: $decoded');
    }
    if (!decoded.containsKey('ecg_id')) {
      throw Exception('Upload JSON missing ecg_id: $decoded');
    }
    return decoded;
  }

  /// ------------------------------
  /// Predict (image / xml / aecg) AND SAVE in same ECGUpload via ecg_id
  /// POST /api/ecg/predict/
  /// ------------------------------
  static Future<http.StreamedResponse> predictUnified({
    required Uint8List fileBytes,
    required String fileName,
    required String patientName,
    required String patientId,
    required int ecgId,
    String? layout, // for images: "3x4" or "3x4+1"
  }) async {
    final uri = Uri.parse('${backendBaseUrl()}/api/ecg/predict/');
    final req = http.MultipartRequest('POST', uri);

    final isImg = _isImage(fileName);
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: isImg
            ? MediaType('image', _inferImageSubtype(fileName))
            : _signalMediaType(fileName),
      ),
    );

    req.fields['patient_name'] = patientName;
    req.fields['patient_id'] = patientId;
    req.fields['ecg_id'] = ecgId.toString();

    if (layout != null && layout.isNotEmpty) {
      req.fields['layout'] = layout;
    }

    return await req.send();
  }

  /// ------------------------------
  /// Auto crop image
  /// POST /api/ecg/auto_crop/
  /// ------------------------------
  static Future<Uint8List> autoCropEcg({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('${backendBaseUrl()}/api/ecg/auto_crop/');
    final req = http.MultipartRequest('POST', uri);

    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
        contentType: MediaType('image', _inferImageSubtype(fileName)),
      ),
    );

    final streamed = await req.send();
    final respBytes = await streamed.stream.toBytes();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final msg = String.fromCharCodes(respBytes);
      throw Exception('auto_crop failed (${streamed.statusCode}): $msg');
    }

    return Uint8List.fromList(respBytes);
  }

  /// ------------------------------
  /// Convenience: upload + predict (Signal)
  /// Returns: {"upload": json, "predictResponse": StreamedResponse}
  /// ------------------------------
  static Future<Map<String, dynamic>> uploadSignalAndPredict({
    required Uint8List fileBytes,
    required String fileName,
    required String patientName,
    required String patientId,
  }) async {
    final uploadJson = await uploadEcgAndGetJson(
      fileBytes: fileBytes,
      fileName: fileName,
      patientName: patientName,
      patientId: patientId,
    );

    final ecgId = (uploadJson['ecg_id'] as num).toInt();

    final pred = await predictUnified(
      fileBytes: fileBytes,
      fileName: fileName,
      patientName: patientName,
      patientId: patientId,
      ecgId: ecgId,
    );

    return {
      "upload": uploadJson,
      "predictResponse": pred,
    };
  }
}