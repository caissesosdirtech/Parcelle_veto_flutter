import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'core/services/auth_service.dart';

void main() {
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
      // Vérification du token au démarrage
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

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    bool isLogged = false;
    try {
      isLogged = await AuthService.isLoggedIn().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      // ✅ Si token présent, tenter un refresh pour vérifier qu'il est valide
      if (isLogged) {
        final refreshOk = await AuthService.refreshToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () => false,
        );
        if (!refreshOk) {
          // Token expiré — on déconnecte et on va au login
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
            // Logo splash
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B4D2E), primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child:
                    Icon(Icons.local_hospital, color: Colors.white, size: 48),
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
            CircularProgressIndicator(color: primary),
          ],
        ),
      ),
    );
  }
}
