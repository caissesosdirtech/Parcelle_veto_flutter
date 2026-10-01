import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:parcelles_veto_flutter/core/services/auth_service.dart';
import 'package:parcelles_veto_flutter/features/auth/login_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Clé du navigateur principal (branchée sur MaterialApp dans main.dart) :
/// permet de renvoyer vers l'écran de connexion depuis n'importe où.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class ApiClient {
  ApiClient._();

  /// Crée un client HTTP qui envoie automatiquement le jeton de connexion.
  /// À utiliser pour TOUS les appels au serveur (sauf la connexion elle-même).
  static Dio authentifie(BaseOptions options) {
    return Dio(options)..interceptors.add(AuthInterceptor());
  }

  static final Dio dio = authentifie(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
}

/// Ajoute « Authorization: Bearer <jeton> » à chaque requête.
/// Sur une erreur 401 : rafraîchit le jeton une fois et relance la requête ;
/// si la session est expirée, déconnecte et affiche l'écran de connexion.
class AuthInterceptor extends Interceptor {
  static bool _redirectionEnCours = false;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (!options.headers.containsKey('Authorization')) {
      final token = await AuthService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final dejaRelancee = options.extra['jeton_rafraichi'] == true;

    if (err.response?.statusCode != 401 || dejaRelancee) {
      handler.next(err);
      return;
    }

    final sessionValide = await AuthService.refreshToken();
    final token = await AuthService.getAccessToken();
    if (sessionValide && token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      options.extra['jeton_rafraichi'] = true;
      try {
        final reponse = await Dio().fetch<dynamic>(options);
        handler.resolve(reponse);
      } on DioException catch (e) {
        handler.next(e);
      }
      return;
    }

    await AuthService.logout();
    _versConnexion();
    handler.next(err);
  }

  static void _versConnexion() {
    if (_redirectionEnCours) return;
    final navigateur = appNavigatorKey.currentState;
    if (navigateur == null) return;
    _redirectionEnCours = true;
    navigateur.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    // Évite plusieurs redirections quand plusieurs appels échouent ensemble.
    Future<void>.delayed(const Duration(seconds: 2), () {
      _redirectionEnCours = false;
    });
  }
}
