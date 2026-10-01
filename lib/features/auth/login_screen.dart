import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const primary = Color(0xFF2E7D4F);

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    ));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── LOGIN ─────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.login(username, password);

      // Force l'enregistrement du token FCM auprès du backend, maintenant
      // que l'utilisateur est authentifié (utile même si l'app était déjà
      // ouverte avant ce login).
      await NotificationService.registerTokenAfterLogin();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
      );
    } on DioException catch (e) {
      setState(() {
        _loading = false;
        if (e.response?.statusCode == 401) {
          _error = 'Identifiant ou mot de passe incorrect.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          _error =
          'Impossible de contacter le serveur.\nVérifiez votre connexion.';
        } else {
          _error = 'Erreur de connexion : ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Une erreur inattendue s\'est produite.';
      });
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── SECTION IMAGE + HEADER ─────────────────────────────────
            _buildImageHeader(),

            // ── FORMULAIRE ANIMÉ ───────────────────────────────────────
            SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    children: [
                      _buildFormCard(),
                      const SizedBox(height: 16),
                      _buildClinicFooter(),
                      const SizedBox(height: 12),
                      const Text(
                        'Parcelles Véto v1.0 · 2026',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── IMAGE HEADER ──────────────────────────────────────────────────────────

  Widget _buildImageHeader() {
    return Stack(
      children: [
        // ── IMAGE de fond (vraie photo)
        SizedBox(
          width: double.infinity,
          height: 280,
          child: Image.asset(
            'assets/images/vet_banner.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF2E7D4F),
              child: const Center(
                child:
                Icon(Icons.local_hospital, size: 80, color: Colors.white54),
              ),
            ),
          ),
        ),

        // ── Dégradé sombre sur l'image
        Container(
          width: double.infinity,
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xCC1B4D2E),
                Color(0x881B4D2E),
                Color(0x001B4D2E),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ),

        // ── Contenu sur l'image
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo + nom
                Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: const Icon(Icons.local_hospital,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parcelles Véto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Dr. Ibrahima Pierre GUISSE',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Badge "En ligne"
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7BFF9E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text('En ligne',
                          style: TextStyle(color: Colors.white, fontSize: 10)),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── FORMULAIRE ────────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 6))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Connexion',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B4D2E)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Accédez à votre espace vétérinaire',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),

        const SizedBox(height: 22),

        // Champ username
        _buildField(
          controller: _usernameCtrl,
          label: 'Nom d\'utilisateur',
          icon: Icons.person_outline,
          hint: 'ex: docteur_guisse',
        ),

        const SizedBox(height: 14),

        // Champ password
        _buildField(
          controller: _passwordCtrl,
          label: 'Mot de passe',
          icon: Icons.lock_outline,
          hint: '••••••••',
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: Colors.grey,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          onSubmitted: (_) => _login(),
        ),

        // Erreur
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFCDD2), width: 0.5),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 22),

        // Bouton connexion
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: primary.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login_rounded, size: 18),
                SizedBox(width: 8),
                Text('Se connecter',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool obscure = false,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        obscureText: obscure,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: const Color(0xFFF8F8F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    ]);
  }

  // ── FOOTER CLINIQUE ───────────────────────────────────────────────────────

  Widget _buildClinicFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8E6C9), width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.location_on_outlined,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Parcelles Assainies, Thiès, Sénégal',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B4D2E))),
            SizedBox(height: 2),
            Text(
              '+221 77 538 57 29 · parcelles-veto@gmail.com',
              style: TextStyle(fontSize: 10, color: Colors.green),
            ),
          ]),
        ),
      ]),
    );
  }
}