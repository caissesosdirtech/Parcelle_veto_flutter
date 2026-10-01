import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _refreshKey = 'auth_refresh_token';
  static const String _usernameKey = 'auth_username';
  static const String _roleKey = 'user_role';

  // Dio SANS intercepteur : sert uniquement à la connexion et au
  // rafraîchissement du jeton (évite toute boucle de rafraîchissement).
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  // 🔐 Connexion via la route JWT de Django (api/token/) :
  // on garde le jeton d'accès ET le jeton de rafraîchissement.
  static Future<void> login(String username, String password) async {
    final response = await _dio.post<dynamic>('api/token/', data: {
      'username': username,
      'password': password,
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data;

      // SimpleJWT renvoie le jeton d'accès dans 'access' (ou parfois 'token')
      final token = data['access'] ?? data['token'];
      final refresh = data['refresh'];
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
      if (refresh != null) {
        await prefs.setString(_refreshKey, refresh.toString());
      }
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

  /// Demande un nouveau jeton d'accès au serveur (api/token/refresh/).
  ///
  /// Renvoie `false` uniquement quand la session n'est plus valable
  /// (pas de jeton de rafraîchissement, ou serveur qui le refuse) :
  /// l'utilisateur doit alors se reconnecter.
  /// Sans réseau, renvoie `true` pour ne pas déconnecter quelqu'un
  /// simplement parce qu'il est hors ligne.
  static Future<bool> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_refreshKey);
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final response = await _dio.post<dynamic>(
        'api/token/refresh/',
        data: {'refresh': refresh},
      );
      final access = response.data is Map ? response.data['access'] : null;
      if (access == null) return false;
      await prefs.setString(_tokenKey, access.toString());
      final nouveauRefresh = response.data['refresh'];
      if (nouveauRefresh != null) {
        await prefs.setString(_refreshKey, nouveauRefresh.toString());
      }
      return true;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 400 || code == 401) return false; // session expirée
      return true; // problème réseau : on garde la session
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // 👉 Alias de getToken, utilisé par plusieurs services
  static Future<String?> getAccessToken() async {
    return getToken();
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }
}
