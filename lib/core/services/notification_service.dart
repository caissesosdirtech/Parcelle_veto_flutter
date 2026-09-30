import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'auth_service.dart';

/// ─────────────────────────────────────────────────────────────────────
/// CONFIGURATION DU CANAL ET DU SON
/// ─────────────────────────────────────────────────────────────────────
/// - kChannelId doit être IDENTIQUE au `channel_id` envoyé par le serveur
///   Django (notifications/firebase_utils.py).
/// - kSoundName = nom du fichier mp3 placé dans
///   android/app/src/main/res/raw/  (SANS l'extension .mp3).
///
/// Un canal Android garde pour toujours le son défini à sa création :
/// pour changer de son plus tard, changez aussi l'ID (v3, v4…) ici ET
/// côté serveur, puis réinstallez l'app.
const String kChannelId = 'parcelle_veto_v2';
const String kChannelName = 'Notifications importantes';
const String kChannelDescription =
    'Ce canal est utilisé pour les alertes importantes avec son.';
const String kSoundName = 'notification2';

/// Handler pour les messages FCM reçus quand l'app est en arrière-plan
/// ou complètement fermée.
///
/// - Doit être une fonction top-level (pas une méthode de classe).
/// - Doit être annotée @pragma('vm:entry-point').
///
/// Quand le message contient un bloc "notification", Android l'affiche
/// automatiquement avec le son du canal : rien à afficher ici.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ignore: avoid_print
  print('📩 Message reçu en arrière-plan : ${message.messageId}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    kChannelId,
    kChannelName,
    description: kChannelDescription,
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(kSoundName),
  );

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  /// Initialise Firebase Cloud Messaging :
  /// - initialise le plugin de notifications locales
  /// - crée le canal Android avec le son personnalisé
  /// - enregistre le handler d'arrière-plan
  /// - demande la permission de notifier
  /// - récupère le token FCM et l'envoie au backend
  /// - écoute les renouvellements de token
  /// - affiche une notification locale quand un message arrive
  ///   pendant que l'app est ouverte au premier plan
  static Future<String?> initialize() async {
    // 1. Initialisation du plugin (indispensable avant tout show()).
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // 2. Création du canal AVEC le son personnalisé, avant tout affichage.
    //    Sinon le plugin le crée tout seul avec le son par défaut du téléphone.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ignore: avoid_print
    print('Autorisation notifications : ${settings.authorizationStatus}');

    final token = await _messaging.getToken();

    // ignore: avoid_print
    print('========================================');
    // ignore: avoid_print
    print('TOKEN FCM :');
    // ignore: avoid_print
    print(token);
    // ignore: avoid_print
    print('========================================');

    if (token != null) {
      await _sendTokenToBackend(token);
    }

    // Le token FCM peut être régénéré à tout moment : on le renvoie
    // systématiquement au backend quand ça arrive.
    _messaging.onTokenRefresh.listen(_sendTokenToBackend);

    // 3. Notifications reçues quand l'app est OUVERTE au premier plan.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              kChannelId,
              kChannelName,
              channelDescription: kChannelDescription,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              sound: RawResourceAndroidNotificationSound(kSoundName),
            ),
          ),
        );
      }
    });

    return token;
  }

  /// Envoie (ou met à jour) le token FCM auprès du backend, associé au
  /// compte actuellement connecté. Réessaie jusqu'à 3 fois.
  static Future<void> _sendTokenToBackend(String token) async {
    final authToken = await AuthService.getAccessToken();
    if (authToken == null) {
      // Pas encore connecté : le token sera renvoyé après le login.
      return;
    }

    const maxTentatives = 3;
    for (var tentative = 1; tentative <= maxTentatives; tentative++) {
      try {
        await _dio.post(
          'notifications/api/register-token/',
          data: {'fcm_token': token},
          options: Options(
            headers: {'Authorization': 'Bearer $authToken'},
          ),
        );

        // ignore: avoid_print
        print('Token FCM envoyé au backend avec succès (tentative $tentative).');
        return;
      } catch (e) {
        // ignore: avoid_print
        print(
          'Échec envoi token FCM (tentative $tentative/$maxTentatives) : $e',
        );

        if (tentative == maxTentatives) {
          // ignore: avoid_print
          print('Abandon après $maxTentatives tentatives.');
          return;
        }

        await Future.delayed(Duration(seconds: tentative));
      }
    }
  }

  /// À appeler juste après un login réussi.
  static Future<void> registerTokenAfterLogin() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _sendTokenToBackend(token);
    }
  }
}