// lib/api/auth_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'api_constants.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  String? _token;
  User? _user;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String _errorMessage = '';

  String? get token => _token;
  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      _token = await _storage.read(key: 'auth_token');
      if (_token != null && _token!.isNotEmpty) {
        await _fetchCurrentUser();
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[_initAuth] Error: $e');
      }
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchCurrentUser() async {
    if (_token == null || _token!.isEmpty) {
      _isAuthenticated = false;
      return;
    }

    final url = Uri.parse('${ApiConstants.baseUrl}/api/users/me/');
    if (kDebugMode) {
      print('[GET /users/me] URL: $url');
    }

    try {
      // Try with Bearer first (SimpleJWT default)
      var resp = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      // If some setups still use 'JWT ' header type
      if (resp.statusCode == 401) {
        if (kDebugMode) {
          print('[GET /users/me] 401 with Bearer, retrying with JWT');
        }
        resp = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'JWT $_token',
          },
        );
      }

      if (kDebugMode) {
        print('[GET /users/me] status: ${resp.statusCode}');
        print('[GET /users/me] body: ${resp.body}');
      }

      if (resp.statusCode == 200) {
        // Try safe parse; don’t crash app if server adds/changes fields.
        try {
          final data = json.decode(resp.body);
          if (data is Map<String, dynamic>) {
            _user = User.fromJsonSafe(data);
          } else {
            _user = null; // unexpected shape, still consider authenticated
          }
        } catch (e) {
          if (kDebugMode) {
            print('[GET /users/me] JSON parse error: $e');
          }
          _user = null; // tolerate parse problems
        }
        _isAuthenticated = true;
      } else {
        // Token invalid/expired/etc.
        await logout();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[GET /users/me] Network/error: $e');
      }
      // Don’t nuke the token on transient errors; mark unauthenticated
      _isAuthenticated = false;
    } finally {
      notifyListeners();
    }
  }
Future<bool> login(String username, String password) async {
  _isLoading = true;
  _errorMessage = '';
  notifyListeners();

  final url = Uri.parse('${ApiConstants.baseUrl}/api/token/');

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body) as Map<String, dynamic>;
      final access = (responseData['access'] ?? '').toString();
      final refresh = (responseData['refresh'] ?? '').toString();

      if (access.isEmpty) {
        _errorMessage = 'Malformed token response.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _token = access;
      await _storage.write(key: 'auth_token', value: access);
      if (refresh.isNotEmpty) {
        await _storage.write(key: 'refresh_token', value: refresh);
      }

      await _fetchCurrentUser();
      _isLoading = false;
      notifyListeners();
      return _isAuthenticated;
    } else if (response.statusCode == 401) {
      _errorMessage = 'Invalid username or password.';
    } else {
      _errorMessage = 'An error occurred. Please try again.';
    }
  } catch (_) {
    _errorMessage = 'Could not connect to the server.';
  }

  _isLoading = false;
  notifyListeners();
  return false;
}

 Future<void> logout() async {
  _token = null;
  _user = null;
  _isAuthenticated = false;
  await _storage.delete(key: 'auth_token');
  await _storage.delete(key: 'refresh_token');
  notifyListeners();
}

}
