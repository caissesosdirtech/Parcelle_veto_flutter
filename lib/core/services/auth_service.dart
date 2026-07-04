import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyRole = 'user_role';
  static const _keyUsername = 'username';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://10.0.2.2:8000/",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // ── LOGIN ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    final res = await _dio.post("api/token/", data: {
      "username": username,
      "password": password,
    });

    final access = res.data['access'] as String;
    final refresh = res.data['refresh'] as String;

    // ✅ Décodage fiable avec dart:convert
    final payload = _decodeJwtPayload(access);
    final role = payload['role'] ?? 'EMPLOYE';
    final user = payload['username'] ?? username;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccess, access);
    await prefs.setString(_keyRefresh, refresh);
    await prefs.setString(_keyRole, role);
    await prefs.setString(_keyUsername, user);

    return {'role': role, 'username': user};
  }

  // ── LOGOUT ────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyUsername);
  }

  // ── GETTERS ───────────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccess);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── REFRESH TOKEN ─────────────────────────────────────────────────────────

  static Future<bool> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString(_keyRefresh);
      if (refresh == null) return false;

      final res = await _dio.post("api/token/refresh/", data: {
        "refresh": refresh,
      });

      final newAccess = res.data['access'] as String;
      await prefs.setString(_keyAccess, newAccess);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── DÉCODAGE JWT ──────────────────────────────────────────────────────────

  /// Décode le payload d'un token JWT avec dart:convert (Base64).
  static Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};

      // ✅ Ajout du padding Base64 correct
      String payload = parts[1];
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        default:
          break;
      }

      // ✅ Base64Url decode + JSON decode avec dart:convert
      final decoded = utf8.decode(base64Url.decode(payload));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
}
