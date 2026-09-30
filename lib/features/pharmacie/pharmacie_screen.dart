import 'package:flutter/material.dart';
import 'pharmacie_service.dart';
import '../../core/services/export_service.dart';
import '../../core/services/permissions_service.dart';

class PharmacieScreen extends StatefulWidget {
  const PharmacieScreen({super.key});

  @override
  State<PharmacieScreen> createState() => _PharmacieScreenState();
}

class _PharmacieScreenState extends State<PharmacieScreen>
    with SingleTickerProviderStateMixin {
  static const primary = Color(0xFF10B981); // Vert émeraude moderne
  static const primaryDark = Color(0xFF047857);
  static const surfaceColor = Color(0xFFF9FAFB);
  static const cardColor = Colors.white;

  final service = PharmacieService();

  List _medicaments = [];
  List _alertes = [];
  List _filtered = [];
  bool _loading = true;
  String? _error;
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    loadData();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await service.getMedicaments();
      final a = await service.getAlertes();
      setState(() {
        _medicaments = m;
        _alertes = a;
        _filtered = m;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur de chargement : $e";
        _loading = false;
      });
    }
  }

  Future<void> _ajouterMedicament(Map<String, dynamic> data) async {
    try {
      await service.ajouterMedicament(data);
      await loadData();
      if (mounted) {
        _showToast('Médicament ajouté avec succès ✅', primary);
      }
    } catch (e) {
      if (mounted) _showToast('Erreur : $e', Colors.red);
    }
  }

  Future<void> _modifierMedicament(int id, Map<String, dynamic> data) async {
    try {
      await service.modifierMedicament(id, data);
      await loadData();
      if (mounted) {
        _showToast('Médicament modifié avec succès ✅', primary);
      }
    } catch (e) {
      if (mounted) _showToast('Erreur : $e', Colors.red);
    }
  }

  Future<void> _supprimerMedicament(int id) async {
    try {
      await service.supprimerMedicament(id);
      await loadData();
      if (mounted) {
        _showToast('Médicament supprimé', Colors.orange);
      }
    } catch (e) {
      if (mounted) _showToast('Erreur : $e', Colors.red);
    }
  }

  void _showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _applySearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _medicaments
          .where((m) =>
      (m['nom'] ?? '').toString().toLowerCase().contains(q) ||
          (m['famille'] ?? '').toString().toLowerCase().contains(q) ||
          (m['fournisseur'] ?? '').toString().toLowerCase().contains(q))
          .toList();
    });
  }

  // ── STATUT & CALCULS ──────────────────────────────────────────────────────

  String _fcfa(num value) {
    final s = value.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  String _statut(dynamic m) {
    final stock = m['stock'] ?? 0;
    final seuil = m['seuil_alerte'] ?? 5;
    if (stock == 0) return 'Rupture';
    if (stock <= seuil) return 'Alerte';
    return 'OK';
  }

  Color _statutColor(String s) {
    switch (s) {
      case 'Rupture':
        return const Color(0xFFDC2626);
      case 'Alerte':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF059669);
    }
  }

  Color _statutBg(String s) {
    switch (s) {
      case 'Rupture':
        return const Color(0xFFFEF2F2);
      case 'Alerte':
        return const Color(0xFFFFFBEB);
      default:
        return const Color(0xFFECFDF5);
    }
  }

  double _barRatio(dynamic m) {
    final stock = (m['stock'] ?? 0) as num;
    final max = stock < 10 ? 10 : stock * 1.5;
    return (stock / max).clamp(0.0, 1.0).toDouble();
  }

  int get _totalValeur {
    return _medicaments.fold(0, (sum, m) {
      final stock = (m['stock'] ?? 0) as num;
      final prix = double.tryParse(m['prix']?.toString() ?? '0') ?? 0;
      return sum + (stock * prix).toInt();
    });
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      body: Column(children: [
        _buildAppBar(),
        if (!_loading && _error == null) ...[
          _buildStats(),
          _buildSearch(),
          _buildTabs(),
        ],
        Expanded(child: _buildBody()),
      ]),
      floatingActionButton: PermissionsService.canEditMedicament
          ? FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: primary,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      )
          : null,
    );
  }

  // ── EXPORT PDF/EXCEL ──────────────────────────────────────────────────────

  Future<void> _exportPharmacie(String format) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: primary)),
    );

    try {
      await ExportService.downloadAndShare(
        endpoint: format == 'pdf' ? 'pharmacie/export/pdf/' : 'pharmacie/export/excel/',
        filename: format == 'pdf' ? 'pharmacie.pdf' : 'pharmacie.xlsx',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showToast('Erreur export : $e', Colors.red);
      }
    }
  }

  // ── APPBAR PREMIUM ────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDark, primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 14),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pharmacie & Stocks',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          SizedBox(height: 2),
          Text('Gestion intelligente de l’inventaire',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: loadData,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  // ── STATS CARDS ───────────────────────────────────────────────────────────

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        _statItem('${_medicaments.length}', 'Médicaments', primary),
        _statDivider(),
        _statItem('${_alertes.length}', 'Alertes', const Color(0xFFEF4444)),
        _statDivider(),
        _statItem(
          _totalValeur > 999 ? '${(_totalValeur / 1000).toStringAsFixed(1)}K' : '$_totalValeur',
          'Valeur Stock',
          const Color(0xFF8B5CF6),
        ),
      ]),
    );
  }

  Widget _statItem(String val, String lbl, Color color) {
    return Expanded(
      child: Column(children: [
        Text(val,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(lbl, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 28, color: const Color(0xFFF3F4F6));

  // ── SEARCH BAR ────────────────────────────────────────────────────────────

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Rechercher un médicament, famille...',
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
              onPressed: () => _searchCtrl.clear(),
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
    );
  }

  // ── TABS ──────────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: [
          const Tab(text: 'Inventaire'),
          Tab(text: 'Alertes (${_alertes.length})'),
        ],
      ),
    );
  }

  // ── BODY ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: loadData,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Réessayer', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ),
      );
    }

    return TabBarView(
      controller: _tabCtrl,
      children: [_buildStockList(), _buildAlertesList()],
    );
  }

  // ── LISTE STOCK ───────────────────────────────────────────────────────────

  Widget _buildStockList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.medication_outlined, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text('Aucun médicament trouvé',
              style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: loadData,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: _filtered.length + 1,
        itemBuilder: (_, i) {
          if (i == _filtered.length) {
            return PermissionsService.canExportPharmacie
                ? Padding(padding: const EdgeInsets.only(top: 10), child: _buildExportButton())
                : const SizedBox.shrink();
          }
          return _buildMedCard(_filtered[i]);
        },
      ),
    );
  }

  Widget _buildExportButton() {
    return PopupMenuButton<String>(
      onSelected: _exportPharmacie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'pdf',
          child: Row(children: [
            Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Exporter en PDF', style: TextStyle(fontSize: 13)),
          ]),
        ),
        const PopupMenuItem(
          value: 'excel',
          child: Row(children: [
            Icon(Icons.table_chart_outlined, size: 18, color: Colors.green),
            SizedBox(width: 10),
            Text('Exporter en Excel', style: TextStyle(fontSize: 13)),
          ]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ios_share, size: 18, color: primary),
            SizedBox(width: 8),
            Text('Exporter l’inventaire',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildMedCard(dynamic m) {
    final statut = _statut(m);
    final ratio = _barRatio(m);
    final prix = double.tryParse(m['prix']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showDetail(m),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statut == 'OK' ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.medication,
                      color: statut == 'OK' ? primary : const Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m['nom'] ?? '',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const SizedBox(height: 2),
                    Text(m['famille'] ?? 'Général',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statutBg(statut),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statut,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statutColor(statut))),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stock : ${m['stock'] ?? 0} unités',
                            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: const Color(0xFFF3F4F6),
                        color: _statutColor(statut),
                        minHeight: 6,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 16),
                Text(_fcfa(prix),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primary)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ── ALERTES LIST ──────────────────────────────────────────────────────────

  Widget _buildAlertesList() {
    if (_alertes.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_outline, size: 50, color: Color(0xFF10B981)),
          const SizedBox(height: 12),
          const Text('Tout est en ordre !',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Aucune alerte de stock critique',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: _alertes.length,
      itemBuilder: (_, i) => _buildAlerteCard(_alertes[i]),
    );
  }

  Widget _buildAlerteCard(dynamic a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['medicament'] ?? '',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
            const SizedBox(height: 4),
            Text(
              'Stock actuel : ${a['stock'] ?? 0}  •  Seuil critique : ${a['seuil'] ?? 5}'
                  '${(a['fournisseur'] ?? '').isNotEmpty ? "  •  ${a['fournisseur']}" : ""}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── DETAIL BOTTOM SHEET ───────────────────────────────────────────────────

  void _showDetail(dynamic m) {
    final statut = _statut(m);
    final prix = double.tryParse(m['prix']?.toString() ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medication, size: 36, color: primary),
          ),
          const SizedBox(height: 12),
          Text(m['nom'] ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(m['famille'] ?? 'Général',
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              _infoRow('Stock actuel', '${m['stock'] ?? 0} unités'),
              _infoRow('Seuil d’alerte', '${m['seuil_alerte'] ?? 5} unités'),
              _infoRow('Prix unitaire', _fcfa(prix)),
              _infoRow('Fournisseur', (m['fournisseur'] ?? '').isNotEmpty ? m['fournisseur'] : '—'),
              _infoRow('Statut', statut),
            ]),
          ),
          const SizedBox(height: 24),
          if (PermissionsService.canEditMedicament)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditDialog(m);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: const BorderSide(color: primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDelete(m);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Supprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
      ]),
    );
  }

  // ── CONFIRMATION SUPPRESSION ──────────────────────────────────────────────

  void _confirmDelete(dynamic m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer le médicament ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer ${m['nom']} ? Cette action est irréversible.',
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _supprimerMedicament(m['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ── DIALOG AJOUT / MODIFICATION ───────────────────────────────────────────

  void _showAddDialog() => _showMedDialog(null);
  void _showEditDialog(dynamic m) => _showMedDialog(m);

  void _showMedDialog(dynamic m) {
    final isEditing = m != null;
    final nomCtrl = TextEditingController(text: isEditing ? m['nom'] ?? '' : '');
    final familleCtrl = TextEditingController(text: isEditing ? m['famille'] ?? '' : '');
    final stockCtrl = TextEditingController(text: isEditing ? '${m['stock'] ?? 0}' : '');
    final prixCtrl = TextEditingController(
        text: isEditing ? double.tryParse(m['prix']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0' : '');
    final seuilCtrl = TextEditingController(text: isEditing ? '${m['seuil_alerte'] ?? 5}' : '5');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEditing ? 'Modifier le médicament' : 'Nouveau médicament',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nomCtrl, 'Nom du médicament *', Icons.medication_outlined),
            const SizedBox(height: 12),
            _dialogField(familleCtrl, 'Famille (ex: Antibiotique)', Icons.category_outlined),
            const SizedBox(height: 12),
            _dialogField(stockCtrl, 'Stock initial *', Icons.inventory_2_outlined, type: TextInputType.number),
            const SizedBox(height: 12),
            _dialogField(prixCtrl, 'Prix unitaire (FCFA) *', Icons.attach_money, type: TextInputType.number),
            const SizedBox(height: 12),
            _dialogField(seuilCtrl, 'Seuil d’alerte', Icons.warning_amber_rounded, type: TextInputType.number),
          ]),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nomCtrl.text.trim().isEmpty || stockCtrl.text.trim().isEmpty || prixCtrl.text.trim().isEmpty) {
                _showToast('Veuillez remplir les champs obligatoires (*)', Colors.orange);
                return;
              }
              Navigator.pop(context);
              final data = {
                'nom': nomCtrl.text.trim(),
                'famille': familleCtrl.text.trim().isNotEmpty ? familleCtrl.text.trim() : 'Général',
                'stock': int.tryParse(stockCtrl.text) ?? 0,
                'prix': double.tryParse(prixCtrl.text) ?? 0,
                'seuil_alerte': int.tryParse(seuilCtrl.text) ?? 5,
              };

              if (isEditing) {
                _modifierMedicament(m['id'], data);
              } else {
                _ajouterMedicament(data);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(isEditing ? 'Enregistrer' : 'Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        prefixIcon: Icon(icon, size: 18, color: primary),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}