import 'package:parcelles_veto_flutter/core/api/api_client.dart';
import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:dio/dio.dart';

class PharmacieService {
  final Dio dio = ApiClient.authentifie(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // ── LISTE (avec id pour CRUD) ─────────────────────────────────────────────
  Future<List<dynamic>> getMedicaments() async {
    try {
      final res = await dio.get("pharmacie/api/liste/");
      if (res.data is Map && res.data['results'] != null) {
        return res.data['results'];
      }
      return res.data;
    } catch (_) {
      return [];
    }
  }

  // ── ALERTES ───────────────────────────────────────────────────────────────
  Future<List<dynamic>> getAlertes() async {
    try {
      final res = await dio.get("pharmacie/api/alertes/");
      return res.data;
    } catch (_) {
      return [];
    }
  }

  // ── AJOUTER ───────────────────────────────────────────────────────────────
  Future<void> ajouterMedicament(Map<String, dynamic> data) async {
    await dio.post("pharmacie/api/ajouter/", data: data);
  }

  // ── MODIFIER ──────────────────────────────────────────────────────────────
  Future<void> modifierMedicament(int id, Map<String, dynamic> data) async {
    await dio.put("pharmacie/api/$id/modifier/", data: data);
  }

  // ── SUPPRIMER ─────────────────────────────────────────────────────────────
  Future<void> supprimerMedicament(int id) async {
    await dio.delete("pharmacie/api/$id/supprimer/");
  }

  // ── STATS ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await dio.get("dashboard/stats/");
      return res.data;
    } catch (_) {
      return {};
    }
  }
}
