import 'dart:math' as math;

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
  // Couleurs du logo : dégradé bleu → vert d'eau
  static const bleu = Color(0xFF0B47C9);
  static const bleuClair = Color(0xFF0A7BD6);
  static const vert = Color(0xFF08C792);
  static const encre = Color(0xFF0F2547);
  static const gris = Color(0xFF6B7A90);
  static const fondChamp = Color(0xFFF2F6FB);

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _logoAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
    ));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
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

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.login(username, password);

      // Force l'enregistrement du token FCM auprès du backend, maintenant
      // que l'utilisateur est authentifié.
      await NotificationService.registerTokenAfterLogin();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.response?.statusCode == 401) {
          _error = 'Identifiant ou mot de passe incorrect.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          _error = 'Impossible de contacter le serveur.\nVérifiez votre connexion.';
        } else {
          _error = 'Erreur de connexion : ${e.message}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Une erreur inattendue s\'est produite.';
      });
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hauteur = MediaQuery.of(context).size.height;
    final hauteurEntete = math.max(300.0, hauteur * 0.42);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildEntete(hauteurEntete),
            // La carte remonte sur le dégradé
            Transform.translate(
              offset: const Offset(0, -36),
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0.0, hauteur - hauteurEntete + 36),
                    ),
                    child: _buildCarte(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── EN-TÊTE : dégradé du logo + empreintes ────────────────────────────────

  Widget _buildEntete(double hauteur) {
    return Container(
      width: double.infinity,
      height: hauteur,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [bleu, bleuClair, vert],
          stops: [0, 0.55, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Empreintes de pattes en filigrane
          ..._empreintes(),
          // Grands cercles lumineux
          Positioned(
            top: -60,
            right: -50,
            child: _cercle(180, 0.10),
          ),
          Positioned(
            bottom: 10,
            left: -70,
            child: _cercle(160, 0.08),
          ),
          // Logo + titre
          SafeArea(
            bottom: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _logoAnim,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: encre.withValues(alpha: 0.30),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/icon/icon.jpg',
                            height: 112,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stack) => const SizedBox(
                              width: 90,
                              height: 90,
                              child: Icon(Icons.pets, size: 48, color: bleu),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          const Text(
                            'Clinique vétérinaire',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dr. Ibrahima Pierre GUISSE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cercle(double taille, double opacite) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacite),
      ),
    );
  }

  List<Widget> _empreintes() {
    // (gauche, haut, taille, rotation en radians)
    const positions = [
      [24.0, 70.0, 26.0, -0.4],
      [300.0, 150.0, 30.0, 0.5],
      [60.0, 210.0, 22.0, 0.2],
      [270.0, 50.0, 20.0, -0.2],
      [330.0, 270.0, 18.0, 0.7],
    ];
    return positions
        .map((p) => Positioned(
              left: p[0],
              top: p[1],
              child: Transform.rotate(
                angle: p[3],
                child: Icon(
                  Icons.pets,
                  size: p[2],
                  color: Colors.white.withValues(alpha: 0.13),
                ),
              ),
            ))
        .toList();
  }

  // ── CARTE DE CONNEXION ────────────────────────────────────────────────────

  Widget _buildCarte() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bon retour 👋',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: encre,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connectez-vous pour accéder à votre espace.',
            style: TextStyle(fontSize: 14, color: gris),
          ),
          const SizedBox(height: 28),

          _buildChamp(
            controller: _usernameCtrl,
            label: 'Nom d\'utilisateur',
            icon: Icons.person_outline_rounded,
            hint: 'ex : docteur_guisse',
            action: TextInputAction.next,
            autofill: const [AutofillHints.username],
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          _buildChamp(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            label: 'Mot de passe',
            icon: Icons.lock_outline_rounded,
            hint: '••••••••',
            obscure: _obscurePassword,
            action: TextInputAction.done,
            autofill: const [AutofillHints.password],
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: gris,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            onSubmitted: (_) => _login(),
          ),

          // Message d'erreur
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _error == null
                ? const SizedBox(height: 0)
                : Container(
                    key: ValueKey(_error),
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFFB91C1C)),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 28),
          _buildBouton(),
          const SizedBox(height: 36),
          _buildPied(),
        ],
      ),
    );
  }

  Widget _buildChamp({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    FocusNode? focusNode,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputAction? action,
    Iterable<String>? autofill,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: encre,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          textInputAction: action,
          autofillHints: autofill,
          onSubmitted: onSubmitted,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          style: const TextStyle(fontSize: 15, color: encre),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFA3AFC0), fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: bleuClair),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fondChamp,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: bleuClair, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBouton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _loading
                ? [bleu.withValues(alpha: 0.6), vert.withValues(alpha: 0.6)]
                : const [bleu, vert],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: _loading
              ? []
              : [
                  BoxShadow(
                    color: bleu.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.4),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Se connecter',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
        ),
      ),
    );
  }

  // ── PIED : coordonnées de la clinique ─────────────────────────────────────

  Widget _buildPied() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade200)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Parcelles Véto · Thiès',
                style: TextStyle(fontSize: 12, color: gris),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade200)),
          ],
        ),
        const SizedBox(height: 14),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            _InfoContact(
              icon: Icons.location_on_outlined,
              texte: 'Parcelles Assainies, Thiès',
            ),
            _InfoContact(
              icon: Icons.phone_outlined,
              texte: '+221 77 538 57 29',
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Version 1.0 · 2026',
          style: TextStyle(fontSize: 11, color: Color(0xFFA3AFC0)),
        ),
      ],
    );
  }
}

class _InfoContact extends StatelessWidget {
  final IconData icon;
  final String texte;

  const _InfoContact({required this.icon, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF0A7BD6)),
        const SizedBox(width: 4),
        Text(
          texte,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A90)),
        ),
      ],
    );
  }
}
