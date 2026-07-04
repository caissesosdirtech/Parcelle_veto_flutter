import 'package:dio/dio.dart';
import 'auth_service.dart';

class DashboardService {
  Future<Dio> _getDio() async {
    final token = await AuthService.getToken();
    return Dio(BaseOptions(
      baseUrl: "http://10.0.2.2:8000/",
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
      return res.data;
    } catch (_) {
      return [];
    }
  }

  Future<List> getFournisseurs() async {
    try {
      final dio = await _getDio();
      final res = await dio.get("fournisseurs/api/liste/");
      return res.data;
    } catch (_) {
      return [];
    }
  }
}
