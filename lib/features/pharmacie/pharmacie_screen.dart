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
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

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
        _error = "Erreur : $e";
        _loading = false;
      });
    }
  }

  Future<void> _ajouterMedicament(Map<String, dynamic> data) async {
    try {
      await service.ajouterMedicament(data);
      await loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Médicament ajouté ✅'), backgroundColor: primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _modifierMedicament(int id, Map<String, dynamic> data) async {
    try {
      await service.modifierMedicament(id, data);
      await loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Médicament modifié ✅'), backgroundColor: primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _supprimerMedicament(int id) async {
    try {
      await service.supprimerMedicament(id);
      await loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Médicament supprimé'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  // ── STATUT ────────────────────────────────────────────────────────────────

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
        return const Color(0xFF991B1B);
      case 'Alerte':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF065F46);
    }
  }

  Color _statutBg(String s) {
    switch (s) {
      case 'Rupture':
        return const Color(0xFFFEF2F2);
      case 'Alerte':
        return const Color(0xFFFFF3E0);
      default:
        return const Color(0xFFECFDF5);
    }
  }

  Color _barColor(String s) {
    switch (s) {
      case 'Rupture':
        return const Color(0xFFE53935);
      case 'Alerte':
        return const Color(0xFFFF9800);
      default:
        return primary;
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
      backgroundColor: const Color(0xFFF2F5F0),
      body: Column(children: [
        _buildAppBar(),
        if (!_loading && _error == null) _buildStats(),
        if (!_loading && _error == null) _buildSearch(),
        if (!_loading && _error == null) _buildTabs(),
        Expanded(child: _buildBody()),
      ]),
      floatingActionButton: PermissionsService.canEditMedicament
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  // ── EXPORT PDF/EXCEL ──────────────────────────────────────────────────────

  Future<void> _exportPharmacie(String format) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: primary)),
    );

    try {
      await ExportService.downloadAndShare(
        endpoint: format == 'pdf'
            ? 'pharmacie/export/pdf/'
            : 'pharmacie/export/excel/',
        filename: format == 'pdf' ? 'pharmacie.pdf' : 'pharmacie.xlsx',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur export : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── APPBAR ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDark, primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('💊 Pharmacie',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          Text('Gestion des stocks & médicaments',
              style: TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: loadData,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.refresh, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── STATS ─────────────────────────────────────────────────────────────────

  Widget _buildStats() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        _statChip(
            '${_medicaments.length}', 'Médicaments', const Color(0xFF2E7D4F)),
        _statDivider(),
        _statChip('${_alertes.length}', 'Alertes', const Color(0xFFE53935)),
        _statDivider(),
        _statChip(
          _totalValeur > 999
              ? '${(_totalValeur / 1000).toStringAsFixed(0)} K'
              : '$_totalValeur',
          'Valeur stock',
          const Color(0xFF6A1B9A),
        ),
      ]),
    );
  }

  Widget _statChip(String val, String lbl, Color color) {
    return Expanded(
      child: Column(children: [
        Text(val,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 2),
        Text(lbl, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    );
  }

  Widget _statDivider() =>
      Container(width: 0.5, height: 32, color: const Color(0xFFE8E8E5));

  // ── SEARCH ────────────────────────────────────────────────────────────────

  Widget _buildSearch() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Rechercher un médicament...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  // ── TABS ──────────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: primary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: [
          const Tab(text: 'Stock complet'),
          Tab(text: '⚠️ Alertes (${_alertes.length})'),
        ],
      ),
    );
  }

  // ── BODY ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: primary));

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: loadData,
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

    return TabBarView(
      controller: _tabCtrl,
      children: [_buildStockList(), _buildAlertesList()],
    );
  }

  // ── LISTE STOCK ───────────────────────────────────────────────────────────

  Widget _buildStockList() {
    if (_filtered.isEmpty) {
      return const Center(
        child: Text('Aucun médicament trouvé',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }
    return RefreshIndicator(
      onRefresh: loadData,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _filtered.length + 1,
        itemBuilder: (_, i) {
          if (i == _filtered.length) {
            return PermissionsService.canExportPharmacie
                ? _buildExportButton()
                : const SizedBox.shrink();
          }
          return _buildMedCard(_filtered[i]);
        },
      ),
    );
  }

  // ── BOUTON EXPORT (footer liste) ─────────────────────────────────────────

  Widget _buildExportButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: PopupMenuButton<String>(
          onSelected: _exportPharmacie,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'pdf',
              child: Row(children: [
                Icon(Icons.picture_as_pdf_outlined,
                    size: 18, color: Colors.red),
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
            decoration: BoxDecoration(
              border: Border.all(color: primary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ios_share, size: 18, color: primary),
                SizedBox(width: 8),
                Text(
                  'Télécharger / Partager le stock',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedCard(dynamic m) {
    final statut = _statut(m);
    final ratio = _barRatio(m);
    final prix = double.tryParse(m['prix']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () => _showDetail(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statut == 'OK'
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Text('💊', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['nom'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(m['famille'] ?? '',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statutBg(statut),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statut,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _statutColor(statut))),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock : ${m['stock'] ?? 0} unités',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: const Color(0xFFE8E8E5),
                        color: _barColor(statut),
                        minHeight: 4,
                      ),
                    ),
                  ]),
            ),
            const SizedBox(width: 12),
            Text(_fcfa(prix),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: primary)),
          ]),
        ]),
      ),
    );
  }

  // ── ALERTES ───────────────────────────────────────────────────────────────

  Widget _buildAlertesList() {
    if (_alertes.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('✅', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('Aucune alerte de stock',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          SizedBox(height: 6),
          Text('Tous les stocks sont suffisants',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _alertes.length,
      itemBuilder: (_, i) => _buildAlerteCard(_alertes[i]),
    );
  }

  Widget _buildAlerteCard(dynamic a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFE53935), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['medicament'] ?? '',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(
              'Stock : ${a['stock'] ?? 0}  •  Seuil : ${a['seuil'] ?? 5}'
              '${(a['fournisseur'] ?? '').isNotEmpty ? "  •  ${a['fournisseur']}" : ""}',
              style: const TextStyle(fontSize: 11, color: Color(0xFFE53935)),
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
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('💊', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(m['nom'] ?? '',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          Text(m['famille'] ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),
          _infoRow('Stock actuel', '${m['stock'] ?? 0} unités'),
          _infoRow('Seuil alerte', '${m['seuil_alerte'] ?? 5} unités'),
          _infoRow('Prix unitaire', _fcfa(prix)),
          _infoRow('Fournisseur',
              (m['fournisseur'] ?? '').isNotEmpty ? m['fournisseur'] : '—'),
          _infoRow('Statut', statut),
          const SizedBox(height: 20),
          // ✅ Boutons action — Docteur seulement
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDelete(m);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Supprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ── CONFIRMER SUPPRESSION ─────────────────────────────────────────────────

  void _confirmDelete(dynamic m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce médicament ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: Text(
            'Voulez-vous supprimer ${m['nom']} ?\nCette action est irréversible.'),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ── DIALOG AJOUT ──────────────────────────────────────────────────────────

  void _showAddDialog() {
    final nomCtrl = TextEditingController();
    final familleCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final prixCtrl = TextEditingController();
    final seuilCtrl = TextEditingController(text: '5');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ajouter un médicament',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nomCtrl, 'Nom *', Icons.medication_outlined),
            const SizedBox(height: 12),
            _dialogField(familleCtrl, 'Famille (ex: Antibiotique)',
                Icons.category_outlined),
            const SizedBox(height: 12),
            _dialogField(stockCtrl, 'Stock *', Icons.inventory_2_outlined,
                type: TextInputType.number),
            const SizedBox(height: 12),
            _dialogField(prixCtrl, 'Prix (FCFA) *', Icons.attach_money,
                type: TextInputType.number),
            const SizedBox(height: 12),
            _dialogField(seuilCtrl, 'Seuil d\'alerte', Icons.warning_outlined,
                type: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nomCtrl.text.trim().isEmpty ||
                  stockCtrl.text.trim().isEmpty ||
                  prixCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Nom, Stock et Prix sont obligatoires'),
                      backgroundColor: Colors.orange),
                );
                return;
              }
              Navigator.pop(context);
              _ajouterMedicament({
                'nom': nomCtrl.text.trim(),
                'famille': familleCtrl.text.trim().isNotEmpty
                    ? familleCtrl.text.trim()
                    : 'Général',
                'stock': int.tryParse(stockCtrl.text) ?? 0,
                'prix': double.tryParse(prixCtrl.text) ?? 0,
                'seuil_alerte': int.tryParse(seuilCtrl.text) ?? 5,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  // ── DIALOG MODIFICATION ───────────────────────────────────────────────────

  void _showEditDialog(dynamic m) {
    final nomCtrl = TextEditingController(text: m['nom'] ?? '');
    final familleCtrl = TextEditingController(text: m['famille'] ?? '');
    final stockCtrl = TextEditingController(text: '${m['stock'] ?? 0}');
    final prixCtrl = TextEditingController(
        text:
            double.tryParse(m['prix']?.toString() ?? '0')?.toStringAsFixed(0) ??
                '0');
    final seuilCtrl = TextEditingController(text: '${m['seuil_alerte'] ?? 5}');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifier le médicament',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nomCtrl, 'Nom *', Icons.medication_outlined),
            const SizedBox(height: 12),
            _dialogField(familleCtrl, 'Famille', Icons.category_outlined),
            const SizedBox(height: 12),
            _dialogField(stockCtrl, 'Stock *', Icons.inventory_2_outlined,
                type: TextInputType.number),
            const SizedBox(height: 12),
            _dialogField(prixCtrl, 'Prix (FCFA)', Icons.attach_money,
                type: TextInputType.number),
            const SizedBox(height: 12),
            _dialogField(seuilCtrl, 'Seuil d\'alerte', Icons.warning_outlined,
                type: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _modifierMedicament(m['id'], {
                'nom': nomCtrl.text.trim(),
                'famille': familleCtrl.text.trim(),
                'stock': int.tryParse(stockCtrl.text) ?? m['stock'],
                'prix': double.tryParse(prixCtrl.text) ?? m['prix'],
                'seuil_alerte':
                    int.tryParse(seuilCtrl.text) ?? m['seuil_alerte'],
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Enregistrer'),
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
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFFAFAF8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }
}
