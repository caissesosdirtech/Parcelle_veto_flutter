import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/permissions_service.dart';

class VentesScreen extends StatefulWidget {
  const VentesScreen({super.key});

  @override
  State<VentesScreen> createState() => _VentesScreenState();
}

class _VentesScreenState extends State<VentesScreen> {
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://10.0.2.2:8000/ventes/",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  List _ventes = [];
  List _filtered = [];
  Map _stats = {};
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rv = await _dio.get("api/liste/");
      final rs = await _dio.get("api/stats/");
      setState(() {
        _ventes = rv.data;
        _filtered = rv.data;
        _stats = rs.data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur : $e";
        _loading = false;
      });
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _ventes
          .where((v) =>
              (v['client'] ?? '').toString().toLowerCase().contains(q) ||
              v['id'].toString().contains(q) ||
              (v['date'] ?? '').toString().contains(q))
          .toList();
    });
  }

  // ── FORMATAGE FCFA ────────────────────────────────────────────────────────
  String _fcfa(dynamic n) {
    final val = double.tryParse(n?.toString() ?? '0') ?? 0;
    final s = val.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0),
      body: Column(children: [
        _buildAppBar(),
        if (!_loading && _error == null) _buildStats(),
        if (!_loading && _error == null) _buildSearch(),
        if (!_loading && _error == null) _buildListHeader(),
        Expanded(child: _buildBody()),
      ]),
    );
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
        // ✅ Flèche de retour
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
          Text('💰 Ventes',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          Text('Historique & statistiques',
              style: TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: _loadData,
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
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Ligne 1
        Row(children: [
          _statCard(
            _fcfa(_stats['total_jour']),
            "Ventes du jour",
            Icons.today_outlined,
            const Color(0xFF1565C0),
          ),
          const SizedBox(width: 10),
          _statCard(
            '${_stats['nb_ventes'] ?? 0}',
            "Total ventes",
            Icons.receipt_long_outlined,
            const Color(0xFF2E7D4F),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _statCard(
            _fcfa(_stats['total_general']),
            "CA total",
            Icons.attach_money,
            const Color(0xFF6A1B9A),
          ),
          const SizedBox(width: 10),
          _statCard(
            _fcfa(_stats['ticket_moyen']),
            "Ticket moyen",
            Icons.analytics_outlined,
            const Color(0xFFE65100),
          ),
        ]),
      ]),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15), width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
        ]),
      ),
    );
  }

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
            hintText: 'Rechercher par client, ID ou date...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  // ── LIST HEADER ───────────────────────────────────────────────────────────
  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        Text('${_filtered.length} vente${_filtered.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('Les 50 dernières',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ]),
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
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
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

    if (_filtered.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('💰', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('Aucune vente trouvée',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _buildVenteCard(_filtered[i]),
      ),
    );
  }

  // ── VENTE CARD ────────────────────────────────────────────────────────────
  Widget _buildVenteCard(dynamic v) {
    final nbLignes = v['nb_lignes'] ?? 0;
    final client = v['client'] ?? '—';
    final hasClient = client != '—';

    return GestureDetector(
      onTap: () => _showVenteDetail(v),
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
        child: Row(children: [
          // Icône
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(11),
            ),
            child:
                const Center(child: Text('🧾', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          // Infos
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Vente #${v['id']}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                if (hasClient)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(client,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF1565C0))),
                  ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.access_time, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(v['date'] ?? '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 10),
                const Icon(Icons.medication_outlined,
                    size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$nbLignes produit${nbLignes > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ]),
          ),
          // Total
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fcfa(v['total']),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ]),
        ]),
      ),
    );
  }

  // ── DETAIL VENTE ──────────────────────────────────────────────────────────
  void _showVenteDetail(dynamic v) {
    final lignes = (v['lignes'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Pill + header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(children: [
                Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(children: [
                  const Text('🧾', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vente #${v['id']}',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w500)),
                        Text(v['date'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ]),
                  const Spacer(),
                  Text(_fcfa(v['total']),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: primary)),
                ]),
                if (v['client'] != '—') ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(v['client'] ?? '',
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey)),
                  ]),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF0F0EE)),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Produits vendus',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 8),
              ]),
            ),
            // Liste lignes
            Expanded(
              child: lignes.isEmpty
                  ? const Center(
                      child: Text('Aucun produit',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: lignes.length,
                      itemBuilder: (_, i) {
                        final l = lignes[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFE8E8E5), width: 0.5),
                          ),
                          child: Row(children: [
                            const Text('💊', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l['medicament'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                        'Qté : ${l['quantite']}  •  PU : ${_fcfa(l['prix_unitaire'])}',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                  ]),
                            ),
                            Text(_fcfa(l['montant_total']),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: primary)),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
