import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'auth_service.dart';

/// Service générique pour télécharger un fichier (PDF/Excel) depuis
/// l'API Django, puis proposer de le partager (WhatsApp, email, etc.)
class ExportService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Télécharge un fichier depuis [endpoint] et ouvre la feuille de partage.
  ///
  /// [endpoint] : chemin relatif, ex. "clients/export/pdf/"
  /// [filename] : nom du fichier local, ex. "clients.pdf"
  /// [queryParameters] : paramètres optionnels (ex. dates pour la caisse)
  static Future<void> downloadAndShare({
    required String endpoint,
    required String filename,
    Map<String, dynamic>? queryParameters,
  }) async {
    final token = await AuthService.getToken();

    final response = await _dio.get(
      endpoint,
      queryParameters: queryParameters,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          if (token != null) "Authorization": "Bearer $token",
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(response.data);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Parcelles Véto — $filename',
    );
  }
}
