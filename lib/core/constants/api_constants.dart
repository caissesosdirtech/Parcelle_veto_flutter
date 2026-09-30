import 'package:parcelles_veto_flutter/core/config/api_config.dart';
// lib/core/constants/api_constants.dart

class ApiConstants {
  // En production, pointe vers l'API Railway
  // En local, pointe vers l'adresse IP de votre PC ou 10.0.2.2 pour l'émulateur
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: ApiConfig.baseUrl,
  );

  // Endpoints d'authentification JWT
  static const String login = '$baseUrl/accounts/token/';
  static const String refresh = '$baseUrl/accounts/token/refresh/';

  // Endpoints Pharmacie / Module Vétérinaire
  static const String pharmacieRecherche = '$baseUrl/pharmacie/recherche/';
}
