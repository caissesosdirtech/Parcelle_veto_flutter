import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _usernameKey = 'auth_username';
  static const String _roleKey = 'user_role';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  static Future isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  // 🔐 Connexion stricte utilisant la route d'API JWT de Django (api/token/)
  static Future login(String username, String password) async {
    final response = await _dio.post('api/token/', data: {
      'username': username,
      'password': password,
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data;

      // SimpleJWT renvoie le jeton d'accès dans 'access' (ou parfois 'token')
      final token = data['access'] ?? data['token'];
      final role = data['role'] ?? 'DOCTOR';

      if (token == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: "Le serveur n'a pas renvoyé de jeton d'accès valide.",
          type: DioExceptionType.badResponse,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token.toString());
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_roleKey, role.toString());
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }

  static Future refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  static Future logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // 👉 Ajout de getAccessToken comme alias direct pour éviter les erreurs de compilation
  static Future getAccessToken() async {
    return await getToken();
  }

  static Future getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }
}