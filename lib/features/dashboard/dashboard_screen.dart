import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../pharmacie/pharmacie_screen.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/permissions_service.dart';
import '../consultations/consultations_screen.dart';
import '../rendez_vous/rendez_vous_screen.dart';
import '../ventes/ventes_screen.dart';
import '../clients/clients_screen.dart';
import '../caisse/caisse_screen.dart';
import '../auth/login_screen.dart';
import '../fournisseurs/fournisseurs_screen.dart';
import '../ventes/vente_journaliere_screen.dart';
import 'package:parcelles_veto_flutter/core/services/notification_router.dart';
import '../parametres/parametres_screen.dart';

// ─────────────────────────────────────────────
// MODELE DE NOTIFICATION
// ─────────────────────────────────────────────
class AppNotification {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final DateTime time;
  bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.time,
    this.read = false,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // ─────────────────────────────────────────────
  // DESIGN SYSTEM
  // ─────────────────────────────────────────────
  static const Color primary = Color(0xFF2E7D4F);
  static const Color primaryDark = Color(0xFF1B4D2E);
  static const Color primaryLight = Color(0xFF4CAF70);
  static const Color background = Color(0xFFF4F6F3);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1F1C);
  static const Color textSecondary = Color(0xFF6B7280);

  final DashboardService service = DashboardService();

  Map<String, dynamic>? stats;
  List<dynamic> stockAlerts = [];
  List<dynamic> fournisseurs = [];

  bool loading = true;
  String? error;

  String _username = '';
  String _role = '';

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _headerController;

  // ─────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _notifTimer;
  final List<AppNotification> _notifications = [];

  int? _lastConsultations;
  int? _lastVentes;
  int? _lastRendezVous;
  int? _lastStockAlertes;

  int get _unreadCount => _notifications.where((n) => !n.read).length;

  @override
  void initState() {
    super.initState();

    // Ouvre le contenu d'une notification appuyée avant l'affichage
    // du tableau de bord (app lancée par la notification).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificationRouter.marquerPret(),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    loadData();
    _loadUser();

    // Vérifie les nouveaux événements toutes les 20 secondes
    _notifTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) => _checkForNewEvents(),
    );
  }

  @override
  void dispose() {
    NotificationRouter.marquerNonPret();
    _searchController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    _headerController.dispose();
    _notifTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // DATA
  // ─────────────────────────────────────────────
  Future<void> loadData() async {
    try {
      await PermissionsService.init();
    } catch (_) {}

    try {
      final s = await service.getStats().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception("Serveur inaccessible (timeout)"),
      );

      final stock = await service.getStockAlerts().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception("Timeout alertes"),
      );

      final f = await service.getFournisseurs().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception("Timeout fournisseurs"),
      );

      if (!mounted) return;

      // Initialise les compteurs de référence pour les notifications
      // (uniquement au premier chargement, pour ne pas notifier à l'ouverture)
      _lastConsultations ??= (num.tryParse('${s['consultations'] ?? 0}') ?? 0).toInt();
      _lastVentes ??= (num.tryParse('${s['ventes_jour'] ?? 0}') ?? 0).toInt();
      _lastRendezVous ??= (num.tryParse('${s['rendez_vous'] ?? 0}') ?? 0).toInt();
      _lastStockAlertes ??= stock.length;

      setState(() {
        stats = s;
        stockAlerts = stock;
        fournisseurs = f;
        loading = false;
        error = null;
      });

      _entranceController.forward(from: 0);
      _headerController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error =
        "Impossible de charger les données.\n\nVérifiez que le serveur est accessible.";
        loading = false;
      });
    }
  }

  Future<void> _loadUser() async {
    final username = await AuthService.getUsername() ?? 'Utilisateur';
    final role = await AuthService.getRole() ?? '';

    if (!mounted) return;
    setState(() {
      _username = username;
      _role = role;
    });
  }

  // ─────────────────────────────────────────────
  // NOTIFICATIONS - VERIFICATION PERIODIQUE
  // ─────────────────────────────────────────────
  Future<void> _checkForNewEvents() async {
    try {
      final s = await service.getStats();
      final stock = await service.getStockAlerts();

      final consultations = (num.tryParse('${s['consultations'] ?? 0}') ?? 0).toInt();
      final ventes = (num.tryParse('${s['ventes_jour'] ?? 0}') ?? 0).toInt();
      final rdv = (num.tryParse('${s['rendez_vous'] ?? 0}') ?? 0).toInt();
      final alertes = stock.length;

      if (_lastConsultations != null && consultations > _lastConsultations!) {
        _pushNotification(
          title: "Nouvelle consultation",
          message: "Une nouvelle consultation vient d'être enregistrée",
          icon: Icons.medical_services_rounded,
          color: primary,
        );
      }
      if (_lastVentes != null && ventes > _lastVentes!) {
        _pushNotification(
          title: "Nouvelle vente",
          message: "Une nouvelle vente vient d'être enregistrée",
          icon: Icons.point_of_sale_rounded,
          color: const Color(0xFF1565C0),
        );
      }
      if (_lastRendezVous != null && rdv > _lastRendezVous!) {
        _pushNotification(
          title: "Nouveau rendez-vous",
          message: "Un nouveau rendez-vous vient d'être pris",
          icon: Icons.calendar_today_rounded,
          color: const Color(0xFF7B1FA2),
        );
      }
      if (_lastStockAlertes != null && alertes > _lastStockAlertes!) {
        _pushNotification(
          title: "Alerte stock",
          message: "Un produit est passé sous le seuil d'alerte",
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFE65100),
        );
      }

      _lastConsultations = consultations;
      _lastVentes = ventes;
      _lastRendezVous = rdv;
      _lastStockAlertes = alertes;

      if (mounted) {
        setState(() {
          stats = s;
          stockAlerts = stock;
        });
      }
    } catch (_) {
      // Vérification silencieuse en arrière-plan : on ignore les erreurs
      // réseau ponctuelles pour ne pas perturber l'utilisateur.
    }
  }

  void _pushNotification({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    if (!mounted) return;
    setState(() {
      _notifications.insert(
        0,
        AppNotification(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          message: message,
          icon: icon,
          color: color,
          time: DateTime.now(),
        ),
      );
    });
    _playNotificationSound();
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (_) {
      // Repli si l'asset audio est manquant ou indisponible
      SystemSound.play(SystemSoundType.alert);
    }
  }

  void _showNotificationsSheet() {
    setState(() {
      for (final n in _notifications) {
        n.read = true;
      }
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (_notifications.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() => _notifications.clear());
                            setSheetState(() {});
                          },
                          child: const Text(
                            "Tout effacer",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: _notifications.isEmpty
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          "Aucune notification",
                          style: TextStyle(color: textSecondary),
                        ),
                      ),
                    )
                        : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = _notifications[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: n.color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: n.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(n.icon, color: n.color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      n.message,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatTime(n.time),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return "il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "il y a ${diff.inHours} h";
    return "${time.day}/${time.month}";
  }

  // ─────────────────────────────────────────────
  // SEARCH
  // ─────────────────────────────────────────────
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await service.searchMedicaments(query);

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _showMedicamentDetails(Map<String, dynamic> med) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.medication_rounded,
                        color: primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      med['nom'] ?? med['medicament'] ?? 'Médicament',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _infoLine("Stock actuel", "${med['stock'] ?? 0} unités"),
              _infoLine(
                  "Seuil d'alerte", "${med['seuil'] ?? med['seuil_alerte'] ?? '-'}"),
              _infoLine(
                  "Prix", _fcfa(med['prix_vente'] ?? med['prix'] ?? 0)),
              _infoLine(
                  "Fournisseur", med['fournisseur'] ?? "Non renseigné"),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Fermer",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: textSecondary, fontSize: 13.5),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────
  void _navigateTo(Widget screen) {
    if (Navigator.canPop(context)) Navigator.pop(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => screen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 320),
        ),
      );
    });
  }

  void _ouvrirNouvelleConsultation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ConsultationsScreen(autoOpenModal: true),
        ),
      );
    });
  }

  void _openVenteModal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VentesScreen()),
      );
    });
  }

  // ─────────────────────────────────────────────
  // DRAWER (MENU LATÉRAL) REGROUPÉ
  // ─────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du menu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryDark, primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Parcelles Véto",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _role.isNotEmpty ? "Espace $_role" : "Espace Employé",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Liste des liens de navigation
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(
                    icon: Icons.dashboard_rounded,
                    title: "Tableau de bord",
                    onTap: () => Navigator.pop(context),
                  ),
                  // Option groupée Clients & Animaux
                  _drawerItem(
                    icon: Icons.people_alt_rounded,
                    title: "Clients & Animaux",
                    onTap: () => _navigateTo(const ClientsScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.medical_services_rounded,
                    title: "Consultations",
                    onTap: () => _navigateTo(const ConsultationsScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.calendar_today_rounded,
                    title: "Rendez-vous",
                    onTap: () => _navigateTo(const RendezVousScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.local_pharmacy_rounded,
                    title: "Pharmacie",
                    onTap: () => _navigateTo(const PharmacieScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.point_of_sale_rounded,
                    title: "Ventes",
                    onTap: () => _navigateTo(const VentesScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.local_shipping_rounded,
                    title: "Fournisseurs",
                    onTap: () => _navigateTo(const FournisseursScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: "Vente du jour",
                    onTap: () => _navigateTo(const VenteJournaliereScreen()),
                  ),
                  const Divider(height: 16),
                  _drawerItem(
                    icon: Icons.settings_rounded,
                    title: "Paramètres",
                    onTap: () => _navigateTo(const ParametresScreen()),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Pied du menu avec profil et déconnexion
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primary.withValues(alpha: 0.15),
                    child: Text(
                      _username.isNotEmpty ? _username[0].toUpperCase() : "U",
                      style: const TextStyle(color: primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _username.isEmpty ? "Utilisateur" : _username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.red),
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      onTap: onTap,
      dense: true,
      horizontalTitleGap: 10,
    );
  }

  // ─────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────
  Future<void> _logout() async {
    // Couleurs du logo (identiques à la page de connexion)
    const bleu = Color(0xFF0B47C9);
    const bleuClair = Color(0xFF0A7BD6);
    const vert = Color(0xFF08C792);
    const encre = Color(0xFF0F2547);
    const gris = Color(0xFF6B7A90);
    const rouge = Color(0xFFDC2626);

    final nom = _username.isEmpty ? 'Utilisateur' : _username;

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      // Sans cela, la fenêtre est limitée à ~56 % de l'écran → débordement
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: encre.withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Bandeau en dégradé avec l'avatar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [bleu, bleuClair, vert],
                      stops: [0, 0.55, 1],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Text(
                            nom[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: bleu,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        nom,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Message
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                  child: Column(
                    children: [
                      const Text(
                        'À bientôt 👋',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: encre,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Voulez-vous vraiment vous déconnecter ?\n'
                        'Vos données restent enregistrées en toute sécurité.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: gris, fontSize: 13.5, height: 1.45),
                      ),
                      const SizedBox(height: 24),

                      // Rester connecté (action principale)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [bleu, vert],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: bleu.withValues(alpha: 0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Rester connecté',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Se déconnecter (action destructive, plus discrète)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: const Text(
                            'Se déconnecter',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: rouge,
                            backgroundColor: const Color(0xFFFEF2F2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      drawer: _buildDrawer(),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: primary,
            backgroundColor: surface,
            onRefresh: loadData,
            child: loading
                ? _buildLoading()
                : error != null
                ? _buildError()
                : CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildTopHeader()),

                // Search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: _reveal(_buildSearch(), 0),
                  ),
                ),

                // Contenu principal (seulement si pas de recherche)
                if (_searchResults.isEmpty && !_isSearching)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _reveal(_buildTodayCard(), 1),
                        const SizedBox(height: 20),
                        _reveal(_sectionTitle("Actions rapides"), 2),
                        const SizedBox(height: 12),
                        _reveal(_buildQuickActions(), 3),
                        const SizedBox(height: 22),
                        _reveal(_sectionTitle("Vue générale"), 4),
                        const SizedBox(height: 12),
                        _reveal(_buildStatsGrid(), 5),
                        const SizedBox(height: 22),
                        _reveal(_sectionTitle("Pharmacie"), 6),
                        const SizedBox(height: 12),
                        _reveal(_buildPharmacyCard(), 7),
                        if (PermissionsService.canSeeValeurStock) ...[
                          const SizedBox(height: 12),
                          _reveal(_buildStockValueCard(), 8),
                        ],
                        const SizedBox(height: 12),
                        _reveal(_buildCashCard(), 9),
                        const SizedBox(height: 20),
                        _reveal(_buildAlerts(), 10),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return AnimatedBuilder(
      animation: _headerController,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_headerController.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(
          children: [
            Builder(
              builder: (ctx) {
                return _HeaderButton(
                  icon: Icons.menu_rounded,
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PARCELLES VÉTO",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: primary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _username.isEmpty
                        ? "Bonjour 👋"
                        : "Bonjour, $_username 👋",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            // ── Cloche de notification ──
            _NotificationBellButton(
              count: _unreadCount,
              onTap: _showNotificationsSheet,
            ),
            const SizedBox(width: 10),
            _HeaderButton(
              icon: Icons.refresh_rounded,
              onTap: () {
                setState(() {
                  loading = true;
                  error = null;
                });
                loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _performSearch,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "Rechercher un médicament…",
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.search_rounded, color: primary, size: 21),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  _performSearch('');
                  setState(() {});
                },
                icon: Icon(Icons.close_rounded,
                    color: Colors.grey.shade500, size: 19),
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: primary,
                  strokeWidth: 2.2,
                ),
              ),
            ),
          if (!_isSearching && _searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 66,
                  color: Colors.grey.shade100,
                ),
                itemBuilder: (_, index) {
                  final med = _searchResults[index];
                  return ListTile(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medication_outlined,
                          color: primary, size: 18),
                    ),
                    title: Text(
                      med['nom'] ?? med['medicament'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "Stock : ${med['stock'] ?? 0}  •  ${_fcfa(med['prix_vente'] ?? med['prix'] ?? 0)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: textSecondary, fontSize: 12),
                    ),
                    onTap: () => _showMedicamentDetails(med),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTodayCard() {
    final consultations =
        num.tryParse('${stats?['consultations'] ?? 0}') ?? 0;
    final ventes = num.tryParse('${stats?['ventes_jour'] ?? 0}') ?? 0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) {
        final t = _pulseController.value;
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryDark,
                primary,
                Color.lerp(primary, primaryLight, t * 0.35)!,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.28 + t * 0.06),
                blurRadius: 20 + t * 4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  "AUJOURD'HUI",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.calendar_today_rounded,
                  color: Colors.white.withValues(alpha: 0.75), size: 16),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Votre activité",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _todayMetric(
                  value: consultations.toInt().toString(),
                  label: "Consultations",
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              Expanded(
                child: _todayMetric(
                  value: _fcfa(ventes),
                  label: "Ventes",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _todayMetric({required String value, required String label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _PremiumAction(
            icon: Icons.medical_services_rounded,
            title: "Consultation",
            subtitle: "Nouveau dossier",
            gradient: const [Color(0xFF2E7D4F), Color(0xFF43A047)],
            onTap: _ouvrirNouvelleConsultation,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PremiumAction(
            icon: Icons.point_of_sale_rounded,
            title: "Vente",
            subtitle: "Nouvelle vente",
            gradient: const [Color(0xFF1565C0), Color(0xFF1E88E5)],
            onTap: _openVenteModal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final animaux = num.tryParse('${stats?['animaux'] ?? 0}') ?? 0;
    final consultations =
        num.tryParse('${stats?['consultations'] ?? 0}') ?? 0;
    final ventes = num.tryParse('${stats?['ventes_jour'] ?? 0}') ?? 0;
    final alertes = num.tryParse('${stats?['stock_alertes'] ?? 0}') ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.pets_rounded,
                title: "Animaux",
                value: animaux.toInt().toString(),
                color: primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.medical_services_outlined,
                title: "Consultations",
                value: consultations.toInt().toString(),
                color: const Color(0xFF1565C0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateTo(const VenteJournaliereScreen()),
                child: _StatTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: "Ventes",
                  value: _fcfa(ventes),
                  color: const Color(0xFF7B1FA2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                icon: Icons.warning_amber_rounded,
                title: "Alertes",
                value: alertes.toInt().toString(),
                color: const Color(0xFFE65100),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPharmacyCard() {
    final meds = num.tryParse('${stats?['medicaments'] ?? 0}') ?? 0;
    final alertes =
        num.tryParse('${stats?['stock_alertes'] ?? stockAlerts.length}') ?? 0;

    return GestureDetector(
      onTap: () => _navigateTo(const PharmacieScreen()),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_pharmacy_rounded, color: primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Gestion Pharmacie",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$meds médicaments répertoriés • $alertes alertes",
                    style: const TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildStockValueCard() {
    return Container();
  }

  Widget _buildCashCard() {
    return GestureDetector(
      onTap: () => _navigateTo(const CaisseScreen()),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.point_of_sale, color: primary),
            SizedBox(width: 12),
            Text("Caisse", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAlerts() {
    if (stockAlerts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Alertes de stock (${stockAlerts.length})"),
        const SizedBox(height: 10),
        ...stockAlerts.map((alert) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alert['nom'] ?? 'Produit en rupture',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Text(
                "Stock: ${alert['stock'] ?? 0}",
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: textPrimary,
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator(color: primary));
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  loading = true;
                  error = null;
                });
                loadData();
              },
              child: const Text("Réessayer"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reveal(Widget child, int index) {
    return child;
  }

  String _fcfa(num amount) {
    return "${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FCFA";
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _DashboardScreenState.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: _DashboardScreenState.textPrimary, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BOUTON CLOCHE DE NOTIFICATION
// ─────────────────────────────────────────────
class _NotificationBellButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBellButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _DashboardScreenState.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              count > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: _DashboardScreenState.textPrimary,
              size: 20,
            ),
            if (count > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _PremiumAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatTile({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _DashboardScreenState.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: _DashboardScreenState.textSecondary)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _DashboardScreenState.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}