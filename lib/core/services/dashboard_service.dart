import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:dio/dio.dart';
import 'auth_service.dart';

class DashboardService {
  Future<Dio> _getDio() async {
    final token = await AuthService.getToken();
    return Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    ));
  }

  Future<Map<String, dynamic>> getStats() async {
    final dio = await _getDio();
    final res = await dio.get("dashboard/stats/");
    return res.data;
  }

  Future<List> getStockAlerts() async {
    try {
      final dio = await _getDio();
      final res = await dio.get("pharmacie/api/alertes/");
      if (res.data is List) return res.data;
      if (res.data is Map && res.data.containsKey('results')) return res.data['results'];
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List> getFournisseurs() async {
    try {
      final dio = await _getDio();
      final res = await dio.get("fournisseurs/api/liste/");
      if (res.data is List) return res.data;
      if (res.data is Map && res.data.containsKey('results')) return res.data['results'];
      return [];
    } catch (_) {
      return [];
    }
  }

  // --- NOUVEAU : Récupération des clients pour les ventes et consultations ---
  Future<List> getClients() async {
    try {
      final dio = await _getDio();
      Response res;
      try {
        res = await dio.get("consultations/api/clients/");
      } catch (_) {
        res = await dio.get("clients/api/");
      }

      if (res.data is List) return res.data;
      if (res.data is Map) {
        if (res.data.containsKey('results')) return res.data['results'];
        if (res.data.containsKey('clients')) return res.data['clients'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- NOUVEAU : Enregistrement effectif de la vente ---
  // --- Enregistrement effectif de la vente avec retour d'erreur précis ---
  Future<String?> enregistrerVente(Map<String, dynamic> donneesVente) async {
    try {
      final dio = await _getDio();
      final res = await dio.post("ventes/api/nouvelle/", data: donneesVente);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return null; // Succès (aucune erreur)
      }
      return "Erreur serveur : ${res.statusCode}";
    } on DioException catch (e) {
      // Tente de récupérer le message d'erreur JSON renvoyé par Django
      if (e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          return data['error'] ?? data['detail'] ?? data.toString();
        }
        return data.toString();
      }
      return e.message;
    } catch (e) {
      try {
        final dio = await _getDio();
        final res = await dio.post("caisse/api/vente/save/", data: donneesVente);
        if (res.statusCode == 200 || res.statusCode == 201) return null;
        return "Erreur alternative : ${res.statusCode}";
      } catch (err) {
        return err.toString();
      }
    }
  }

  // Historique global des ventes
  Future<List> getVentes() async {
    try {
      final dio = await _getDio();
      final res = await dio.get("ventes/api/liste/");
      if (res.data is List) return res.data;
      if (res.data is Map && res.data.containsKey('results')) return res.data['results'];
      return [];
    } catch (e) {
      return [];
    }
  }

  // Ventes du jour
  Future<List> getVentesDuJour() async {
    try {
      final dio = await _getDio();
      final res = await dio.get("ventes/api/aujourdhui/");
      if (res.data is List) return res.data;
      if (res.data is Map && res.data.containsKey('results')) return res.data['results'];
      return [];
    } catch (e) {
      return [];
    }
  }

  // Liste des consultations
  Future<List> getConsultations() async {
    try {
      final dio = await _getDio();
      final res = await dio.get("consultations/api/liste/");
      if (res.data is List) return res.data;
      if (res.data is Map && res.data.containsKey('results')) return res.data['results'];
      return [];
    } catch (e) {
      return [];
    }
  }

  // Recherche rapide de médicaments
  Future<List> searchMedicaments(String query) async {
    try {
      final dio = await _getDio();
      final res = await dio.get("pharmacie/api/medicaments/?search=$query");
      if (res.data is List) return res.data;
      if (res.data is Map && res.data.containsKey('results')) return res.data['results'];
      return [];
    } catch (e) {
      return [];
    }
  }
}