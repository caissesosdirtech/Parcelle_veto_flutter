import 'package:flutter/material.dart';
import '../pharmacie/pharmacie_screen.dart';
import '../animaux/animaux_screen.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/permissions_service.dart';
import '../consultations/consultations_screen.dart';
import '../ventes/ventes_screen.dart';
import '../clients/clients_screen.dart';
import '../caisse/caisse_screen.dart';
import '../auth/login_screen.dart';
import '../fournisseurs/fournisseurs_screen.dart';
import '../ventes/vente_journaliere_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

  final service = DashboardService();

  Map<String, dynamic>? stats;
  List stockAlerts = [];
  List fournisseurs = [];

  bool loading = true;
  String? error;

  // ✅ Infos utilisateur connecté
  String _username = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    loadData();
    _loadUser();
  }

  // ── CHARGEMENT DONNÉES ────────────────────────────────────────────────────

  Future<void> loadData() async {
    // ✅ Initialise les permissions selon le rôle stocké
    try {
      await PermissionsService.init();
    } catch (_) {}

    try {
      final s = await service.getStats().timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception("Serveur inaccessible (timeout)"),
          );
      final stock = await service.getStockAlerts().timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception("Timeout alertes"),
          );
      final f = await service.getFournisseurs().timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception("Timeout fournisseurs"),
          );
      setState(() {
        stats = s;
        stockAlerts = stock;
        fournisseurs = f;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error =
            "Erreur : $e\n\nVérifiez que le serveur Django est démarré\net que l'émulateur peut l'atteindre.";
        loading = false;
      });
    }
  }

  // ✅ Chargement infos utilisateur depuis le token stocké
  Future<void> _loadUser() async {
    final username = await AuthService.getUsername() ?? 'Utilisateur';
    final role = await AuthService.getRole() ?? 'EMPLOYE';
    setState(() {
      _username = username;
      _role = role;
    });
  }

  // ── NAVIGATION ────────────────────────────────────────────────────────────

  void _navigateTo(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ✅ Déconnexion avec confirmation
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
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

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0),
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Parcelles Véto',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                loading = true;
                error = null;
              });
              loadData();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  // ── BODY ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: primary));
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  loading = true;
                  error = null;
                });
                loadData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadData,
      color: primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── STATS GÉNÉRALES ────────────────────────────────────────
            _sectionTitle('📊 Vue générale'),
            const SizedBox(height: 10),
            Row(children: [
              _buildStatCard('Animaux', stats?['animaux']?.toString() ?? '0',
                  Icons.pets, const Color(0xFF2E7D4F)),
              const SizedBox(width: 10),
              _buildStatCard(
                  'Consultations',
                  stats?['consultations']?.toString() ?? '0',
                  Icons.calendar_today,
                  const Color(0xFF1565C0)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _navigateTo(const VenteJournaliereScreen()),
                  child: _buildStatCardContent(
                      'Ventes/jour',
                      _fcfa(stats?["ventes_jour"] ?? 0),
                      Icons.attach_money,
                      const Color(0xFF6A1B9A)),
                ),
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                  'Alertes stock',
                  stats?['stock_alertes']?.toString() ?? '0',
                  Icons.warning,
                  const Color(0xFFE65100)),
            ]),

            const SizedBox(height: 24),

            // ── PHARMACIE ──────────────────────────────────────────────
            _sectionTitle('💊 Pharmacie'),
            const SizedBox(height: 10),
            _buildPharmacieStats(),
            const SizedBox(height: 14),
            if (PermissionsService.canSeeValeurStock) ...[
              _buildValeurStock(),
              const SizedBox(height: 14),
            ],

            if (stockAlerts.isNotEmpty) ...[
              _buildAlertesSection(),
              const SizedBox(height: 24),
            ] else ...[
              _buildNoAlerte(),
              const SizedBox(height: 24),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── DRAWER ────────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // En-tête
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryDark, primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_hospital,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(height: 12),
                const Text('Parcelles Véto',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                const Text('Gestion vétérinaire',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),

          // Items de navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerSection('PRINCIPAL'),
                _drawerItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  onTap: () => Navigator.pop(context),
                  active: true,
                ),
                _drawerItem(
                  icon: Icons.pets_outlined,
                  label: 'Animaux',
                  onTap: () => _navigateTo(const AnimauxScreen()),
                ),
                _drawerItem(
                  icon: Icons.people_outline,
                  label: 'Clients',
                  onTap: () => _navigateTo(const ClientsScreen()),
                ),
                const Divider(height: 16, indent: 16, endIndent: 16),
                _drawerSection('CLINIQUE'),
                _drawerItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Consultations & RDV',
                  onTap: () => _navigateTo(const ConsultationsScreen()),
                ),
                _drawerItem(
                  icon: Icons.local_pharmacy_outlined,
                  label: 'Pharmacie',
                  onTap: () => _navigateTo(const PharmacieScreen()),
                  badge:
                      stockAlerts.isNotEmpty ? '${stockAlerts.length}' : null,
                ),
                _drawerItem(
                  icon: Icons.point_of_sale_outlined,
                  label: 'Ventes',
                  onTap: () => _navigateTo(const VentesScreen()),
                ),
                _drawerItem(
                  icon: Icons.local_shipping_outlined,
                  label: 'Fournisseurs',
                  onTap: () => _navigateTo(const FournisseursScreen()),
                  badge:
                      fournisseurs.isNotEmpty ? '${fournisseurs.length}' : null,
                ),

                // ✅ Section FINANCES — visible Docteur seulement
                if (PermissionsService.canVoirCaisse) ...[
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  _drawerSection('FINANCES'),
                  _drawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Rapport Caisse',
                    onTap: () => _navigateTo(const CaisseScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.today_outlined,
                    label: 'Vente du jour',
                    onTap: () => _navigateTo(const VenteJournaliereScreen()),
                  ),
                ],

                // ✅ Vente du jour seule — visible Assistant aussi
                if (!PermissionsService.canVoirCaisse) ...[
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  _drawerSection('VENTES'),
                  _drawerItem(
                    icon: Icons.today_outlined,
                    label: 'Vente du jour',
                    onTap: () => _navigateTo(const VenteJournaliereScreen()),
                  ),
                ],
              ],
            ),
          ),

          // ✅ Pied du drawer avec username, rôle et bouton déconnexion
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: Color(0xFFE8E8E5), width: 0.5)),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.person_outline, color: primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _username.isNotEmpty ? _username : 'Utilisateur',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _role == 'DOCTEUR' ? 'Docteur' : 'Employé',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ]),
              ),
              // ✅ Bouton déconnexion
              IconButton(
                icon: const Icon(Icons.logout, size: 20, color: Colors.red),
                tooltip: 'Déconnexion',
                onPressed: _logout,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _drawerSection(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.8)),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    String? badge,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(icon, size: 20, color: active ? primary : Colors.grey[600]),
      title: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w500 : FontWeight.normal,
              color: active ? primary : Colors.black87)),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(badge,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.w500)),
            )
          : null,
      tileColor: active ? const Color(0xFFE8F5E9) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }

  // ── PHARMACIE WIDGETS ─────────────────────────────────────────────────────

  Widget _buildPharmacieStats() {
    final nbMeds = stats?['medicaments'] ?? 0;
    final nbAlertes = stats?['stock_alertes'] ?? stockAlerts.length;
    final nbRuptures = stockAlerts.where((a) => (a['stock'] ?? 1) == 0).length;

    return Row(children: [
      _buildStatCard('Médicaments', '$nbMeds', Icons.medication_outlined,
          const Color(0xFF00796B)),
      const SizedBox(width: 10),
      _buildStatCard('En alerte', '$nbAlertes', Icons.warning_amber_outlined,
          const Color(0xFFE65100)),
      const SizedBox(width: 10),
      _buildStatCard('Ruptures', '$nbRuptures',
          Icons.remove_shopping_cart_outlined, Colors.red),
    ]);
  }

  Widget _buildValeurStock() {
    final valeur = stats?['valeur_stock'] ?? 0;
    final valeurStr = _fcfa(valeur);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryDark, primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 28),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Valeur totale du stock',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(valeurStr,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => _navigateTo(const PharmacieScreen()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Voir',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
      ]),
    );
  }

  Widget _buildAlertesSection() {
    final ruptures = stockAlerts.where((a) => (a['stock'] ?? 1) == 0).toList();
    final alertes = stockAlerts.where((a) => (a['stock'] ?? 1) > 0).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (ruptures.isNotEmpty) ...[
        _alertHeader('🔴 Ruptures de stock', Colors.red),
        const SizedBox(height: 6),
        ...ruptures.map((a) => _alerteTile(a, isRupture: true)),
        const SizedBox(height: 12),
      ],
      if (alertes.isNotEmpty) ...[
        _alertHeader('🟠 Stock sous le seuil', const Color(0xFFE65100)),
        const SizedBox(height: 6),
        ...alertes.map((a) => _alerteTile(a, isRupture: false)),
      ],
    ]);
  }

  Widget _alertHeader(String title, Color color) {
    return Row(children: [
      Text(title,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: color.withOpacity(0.3), height: 1)),
    ]);
  }

  Widget _alerteTile(dynamic item, {required bool isRupture}) {
    final bgColor =
        isRupture ? const Color(0xFFFEF2F2) : const Color(0xFFFFF3E0);
    final borderColor =
        isRupture ? const Color(0xFFFFCDD2) : const Color(0xFFFFE0B2);
    final iconColor = isRupture ? Colors.red : const Color(0xFFE65100);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(children: [
        Icon(
            isRupture
                ? Icons.remove_shopping_cart_outlined
                : Icons.warning_amber_rounded,
            color: iconColor,
            size: 18),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['medicament'] ?? '',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text(
              isRupture
                  ? 'Rupture totale'
                  : 'Stock : ${item['stock'] ?? 0}  •  Seuil : ${item['seuil'] ?? 5}',
              style: TextStyle(fontSize: 11, color: iconColor),
            ),
          ]),
        ),
        if ((item['fournisseur'] ?? '').isNotEmpty)
          Text(item['fournisseur'],
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    );
  }

  Widget _buildNoAlerte() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 0.5),
      ),
      child: const Row(children: [
        Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 20),
        SizedBox(width: 10),
        Text('Tous les stocks sont suffisants',
            style: TextStyle(fontSize: 13, color: Color(0xFF065F46))),
      ]),
    );
  }

  // ── WIDGETS COMMUNS ───────────────────────────────────────────────────────

  String _fcfa(num value) {
    final s = value.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: _buildStatCardContent(title, value, icon, color),
    );
  }

  /// Contenu de la carte stat, réutilisable dans un GestureDetector
  /// (ex: carte "Ventes/jour" cliquable vers VenteJournaliereScreen).
  Widget _buildStatCardContent(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: color)),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    );
  }
}
