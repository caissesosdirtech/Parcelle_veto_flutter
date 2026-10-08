import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/config/api_config.dart';

/// Appels au serveur pour la rubrique Paramètres.
class ParametresApi {
  static final Dio _dio = ApiClient.authentifie(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  /// Message d'erreur lisible renvoyé par le serveur.
  static String erreur(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Impossible de contacter le serveur.';
      }
    }
    return 'Une erreur est survenue.';
  }

  static Future<Map<String, dynamic>> utilisateurs() async {
    final r = await _dio.get('parametres/api/utilisateurs/');
    return Map<String, dynamic>.from(r.data as Map);
  }

  static Future<String> creer(Map<String, dynamic> donnees) async {
    final r = await _dio.post('parametres/api/utilisateurs/', data: donnees);
    return (r.data['message'] ?? 'Compte créé.').toString();
  }

  static Future<String> modifier(int id, Map<String, dynamic> donnees) async {
    final r = await _dio.post('parametres/api/utilisateurs/$id/', data: donnees);
    return (r.data['message'] ?? 'Compte mis à jour.').toString();
  }

  static Future<String> reinitialiserMotDePasse(int id, String mdp) async {
    final r = await _dio.post('parametres/api/utilisateurs/$id/mot-de-passe/',
        data: {'password': mdp});
    return (r.data['message'] ?? 'Mot de passe réinitialisé.').toString();
  }

  static Future<String> basculerActif(int id) async {
    final r = await _dio.post('parametres/api/utilisateurs/$id/activer/');
    return (r.data['message'] ?? 'Statut modifié.').toString();
  }

  static Future<Map<String, dynamic>> monCompte() async {
    final r = await _dio.get('parametres/api/mon-compte/');
    return Map<String, dynamic>.from(r.data['utilisateur'] as Map);
  }

  static Future<void> enregistrerMonCompte(Map<String, dynamic> donnees) async {
    await _dio.post('parametres/api/mon-compte/', data: donnees);
  }

  static Future<String> changerMonMotDePasse(String ancien, String nouveau) async {
    final r = await _dio.post('parametres/api/mon-compte/mot-de-passe/',
        data: {'ancien': ancien, 'password': nouveau});
    return (r.data['message'] ?? 'Mot de passe changé.').toString();
  }

  /// Réglages de la clinique : {clinique: {...}, modifiable: bool}
  static Future<Map<String, dynamic>> clinique() async {
    final r = await _dio.get('parametres/api/clinique/');
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// Enregistre les réglages ; renvoie (réglages à jour, message).
  static Future<(Map<String, dynamic>, String)> enregistrerClinique(
      Map<String, dynamic> donnees) async {
    final r = await _dio.post('parametres/api/clinique/', data: donnees);
    return (
      Map<String, dynamic>.from(r.data['clinique'] as Map),
      (r.data['message'] ?? 'Réglages enregistrés.').toString(),
    );
  }
}
