import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';

import 'firebase_options.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    print("🔥 ========================================== 🔥");
    print("🔥 MON TOKEN FCM : $fcmToken");
    print("🔥 ========================================== 🔥");
  } catch (e) {
    print("Erreur récupération FCM Token: $e");
  }

  // Supprime l'ancien canal 'high_importance_channel' (ancien son),
  // qui n'est plus utilisé : le serveur envoie désormais sur
  // 'parcelle_veto_v2', créé dans NotificationService.initialize().
  try {
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannel('high_importance_channel');
  } catch (e) {
    print('Suppression ancien canal : $e');
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    print('Erreur initialisation notifications : $e');
  }

  runApp(const ParcellsVetoApp());
}

class ParcellsVetoApp extends StatelessWidget {
  const ParcellsVetoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parcelles Véto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D4F),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const _SplashRouter(),
    );
  }
}

/// Vérifie si un token existe et redirige vers Login ou Dashboard.
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  static const primary = Color(0xFF2E7D4F);

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future _checkAuth() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    bool isLogged = false;

    try {
      isLogged = await AuthService.isLoggedIn().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (isLogged) {
        final refreshOk = await AuthService.refreshToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () => false,
        );

        if (refreshOk) {
          final String? jwtToken = await AuthService.getAccessToken();
          if (jwtToken != null) {
            final dio = Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              headers: {
                'Authorization': 'Bearer $jwtToken',
                'Content-Type': 'application/json',
              },
            ));

            await envoyerFcmTokenAuServeur(dio);
          }
        } else {
          await AuthService.logout();
          isLogged = false;
        }
      }
    } catch (_) {
      isLogged = false;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        isLogged ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF2F5F0),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1B4D2E),
                    primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Icon(
                  Icons.local_hospital,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Parcelles Véto',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B4D2E),
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              color: primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// ── FONCTION D'ENVOI DU TOKEN FCM AU SERVEUR DJANGO ──
Future envoyerFcmTokenAuServeur(Dio dio) async {
  try {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      final response = await dio.post(
        'notifications/api/register-token/',
        data: {'fcm_token': fcmToken},
      );
      print("✅ Token FCM enregistré sur le serveur : ${response.data}");
    }
  } catch (e) {
    print("❌ Erreur lors de l'envoi du token FCM : $e");
  }
}