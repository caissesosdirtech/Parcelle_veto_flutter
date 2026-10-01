import 'package:parcelles_veto_flutter/core/api/api_client.dart';
import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/export_service.dart';

class CaisseScreen extends StatefulWidget {
  const CaisseScreen({super.key});

  @override
  State<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends State<CaisseScreen> {
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

  final Dio _dio = ApiClient.authentifie(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  List<dynamic> _ventes = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;

  // Filtres période
  DateTime? _dateDebut;
  DateTime? _dateFin;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, String>{};
      if (_dateDebut != null) {
        params['date_debut'] = _formatDate(_dateDebut!);
      }
      if (_dateFin != null) {
        params['date_fin'] = _formatDate(_dateFin!);
      }

      final res = await _dio.get(
        "caisse/api/rapport/",
        queryParameters: params,
      );

      setState(() {
        _stats = res.data['stats'] ?? {};
        _ventes = res.data['ventes'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur de connexion : $e";
        _loading = false;
      });
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDateFr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatMontant(dynamic val) {
    final n = (val is num) ? val.toInt() : int.tryParse('$val') ?? 0;
    final s = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  // ── SÉLECTION DATE ────────────────────────────────────────────────────────

  Future<void> _pickDate({required bool isDebut}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDebut ? (_dateDebut ?? now) : (_dateFin ?? now),
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDebut) {
          _dateDebut = picked;
        } else {
          _dateFin = picked;
        }
      });
      _loadData();
    }
  }

  void _clearFiltres() {
    setState(() {
      _dateDebut = null;
      _dateFin = null;
    });
    _loadData();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0),
      body: Column(
        children: [
          _buildAppBar(),
          _buildFiltres(),
          Expanded(child: _buildBody()),
        ],
      ),
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
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('💰 Rapport Caisse',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          Text('Suivi des recettes',
              style: TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: _loadData,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.refresh, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── FILTRES PÉRIODE ───────────────────────────────────────────────────────

  Widget _buildFiltres() {
    final hasFiltres = _dateDebut != null || _dateFin != null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        // Date début
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(isDebut: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _dateDebut != null ? primary : const Color(0xFFDDDDDD),
                  width: 0.5,
                ),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14,
                    color: _dateDebut != null ? primary : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  _dateDebut != null
                      ? _formatDateFr(_dateDebut!)
                      : 'Date début',
                  style: TextStyle(
                      fontSize: 12,
                      color: _dateDebut != null ? primary : Colors.grey),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text('→', style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(width: 8),
        // Date fin
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(isDebut: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _dateFin != null ? primary : const Color(0xFFDDDDDD),
                  width: 0.5,
                ),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: _dateFin != null ? primary : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  _dateFin != null ? _formatDateFr(_dateFin!) : 'Date fin',
                  style: TextStyle(
                      fontSize: 12,
                      color: _dateFin != null ? primary : Colors.grey),
                ),
              ]),
            ),
          ),
        ),
        // Bouton effacer filtres
        if (hasFiltres) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _clearFiltres,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.red),
            ),
          ),
        ],
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

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // ── STATS CARDS ──────────────────────────────────────────────
          _buildStatsGrid(),
          const SizedBox(height: 16),

          // ── BANDEAU TOTAL ─────────────────────────────────────────────
          _buildTotalBandeau(),
          const SizedBox(height: 20),

          // ── LISTE VENTES ──────────────────────────────────────────────
          _buildVentesHeader(),
          const SizedBox(height: 10),
          if (_ventes.isEmpty)
            _buildEmpty()
          else
            ..._ventes.map((v) => _buildVenteTile(v)),

          // ✅ Bouton export PDF/Excel sous la liste
          if (_ventes.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: PopupMenuButton<String>(
                onSelected: _exportCaisse,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                      Icon(Icons.table_chart_outlined,
                          size: 18, color: Colors.green),
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
                        'Télécharger / Partager le rapport',
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
          ],
        ],
      ),
    );
  }

  // ── STATS GRID ────────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final nbVentes = _stats['nombre_ventes'] ?? _ventes.length;
    final recettesJour = _stats['recettes_jour'] ?? 0;
    final ticketMoyen = _stats['ticket_moyen'] ?? 0;

    return Column(children: [
      Row(children: [
        _statCard(
          'Recettes du jour',
          _formatMontant(recettesJour),
          Icons.today,
          const Color(0xFF2E7D4F),
        ),
        const SizedBox(width: 10),
        _statCard(
          'Nb ventes',
          '$nbVentes',
          Icons.receipt_long_outlined,
          const Color(0xFF1565C0),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _statCard(
          'Ticket moyen',
          _formatMontant(ticketMoyen),
          Icons.analytics_outlined,
          const Color(0xFF6A1B9A),
        ),
        const SizedBox(width: 10),
        _statCard(
          'Période',
          _dateDebut != null
              ? '${_formatDateFr(_dateDebut!)} → ${_dateFin != null ? _formatDateFr(_dateFin!) : "auj."}'
              : 'Toutes',
          Icons.date_range_outlined,
          const Color(0xFF00796B),
        ),
      ]),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: color),
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

  // ── BANDEAU TOTAL ─────────────────────────────────────────────────────────

  Widget _buildTotalBandeau() {
    final total = _stats['total_recettes'] ?? 0;
    final totalStr = _formatMontant(total);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryDark, primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.account_balance_wallet_outlined,
            color: Colors.white70, size: 32),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total des recettes',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(totalStr,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          if (_dateDebut != null || _dateFin != null)
            Text(
              'Période filtrée',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
            ),
        ]),
      ]),
    );
  }

  // ── LISTE VENTES ──────────────────────────────────────────────────────────

  Widget _buildVentesHeader() {
    return Row(children: [
      const Text('📋 Détail des ventes',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('${_ventes.length} vente${_ventes.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 11, color: primaryDark)),
      ),
    ]);
  }

  Widget _buildVenteTile(dynamic vente) {
    final isOrdonnance = (vente['type'] ?? '') == 'Ordonnance';
    final montant = vente['montant'] ?? vente['total'] ?? 0;
    final client = vente['client'] ?? 'Anonyme';
    final animal = vente['animal'] ?? '';
    final date = vente['date'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Row(children: [
        // Icône type
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isOrdonnance
                ? const Color(0xFFE3F2FD)
                : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isOrdonnance
                ? Icons.description_outlined
                : Icons.shopping_cart_outlined,
            color: isOrdonnance ? const Color(0xFF1565C0) : primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        // Infos vente
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(client,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(
              [
                isOrdonnance ? 'Ordonnance' : 'Vente directe',
                if (animal.isNotEmpty) '• $animal',
              ].join(' '),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ]),
        ),
        // Montant + date
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            _formatMontant(montant),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: primary),
          ),
          const SizedBox(height: 3),
          Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('💰', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        const Text('Aucune vente sur cette période',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('Modifiez les filtres de période',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ]),
    );
  }

  // ── EXPORT PDF/EXCEL ──────────────────────────────────────────────────────

  Future<void> _exportCaisse(String format) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: primary)),
    );

    final params = <String, dynamic>{};
    if (_dateDebut != null) params['date_debut'] = _formatDate(_dateDebut!);
    if (_dateFin != null) params['date_fin'] = _formatDate(_dateFin!);

    try {
      await ExportService.downloadAndShare(
        endpoint:
            format == 'pdf' ? 'caisse/rapport/pdf/' : 'caisse/export/excel/',
        filename:
            format == 'pdf' ? 'rapport_caisse.pdf' : 'rapport_caisse.xlsx',
        queryParameters: params,
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
}
