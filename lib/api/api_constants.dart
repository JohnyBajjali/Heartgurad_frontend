// lib/api/api_constants.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiConstants {
  /// Use emulator loopback for Android, localhost elsewhere.
  /// If you later target Web, switch this to your LAN/IP/HTTPS.
  static String get baseUrl {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }
}
