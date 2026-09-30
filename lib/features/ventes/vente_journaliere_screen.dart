import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/export_service.dart';
import '../../core/services/auth_service.dart';

class VenteJournaliereScreen extends StatefulWidget {
  const VenteJournaliereScreen({super.key});

  @override
  State<VenteJournaliereScreen> createState() => _VenteJournaliereScreenState();
}

class _VenteJournaliereScreenState extends State<VenteJournaliereScreen> {
  // Couleurs adaptées au thème bleu et blanc corporate
  static const primary = Color(0xFF1976D2);
  static const primaryDark = Color(0xFF0D47A1);

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── HELPER DIO AVEC AUTHENTIFICATION ────────────────────────────────────────

  Future<Dio> _getDio() async {
    final token = await AuthService.getToken();
    return Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        "Content-Type": "application/json",
        if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
      },
    ));
  }

  // ── API ───────────────────────────────────────────────────────────────────

  String get _dateParam =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = await _getDio();
      final res = await dio.get("ventes/api/vente-jour/", queryParameters: {
        'date': _dateParam,
      });
      setState(() {
        _data = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur de chargement : $e";
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  // ── EXPORT ────────────────────────────────────────────────────────────────

  Future<void> _export(String format) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
      const Center(child: CircularProgressIndicator(color: primary)),
    );

    try {
      await ExportService.downloadAndShare(
        endpoint: format == 'pdf'
            ? 'ventes/export/jour/pdf/'
            : 'ventes/export/jour/excel/',
        filename: format == 'pdf'
            ? 'vente_du_jour_$_dateParam.pdf'
            : 'vente_du_jour_$_dateParam.xlsx',
        queryParameters: {'date': _dateParam},
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

  // ── HELPERS ───────────────────────────────────────────────────────────────

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

  String _formatDateFr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(children: [
        _buildAppBar(),
        _buildDateBar(),
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
          Text('📆 Vente du jour',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          Text('Détail journalier des recettes',
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

  // ── BARRE DATE ────────────────────────────────────────────────────────────

  Widget _buildDateBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: primary),
            const SizedBox(width: 8),
            Text(
              _isToday
                  ? 'Aujourd\'hui — ${_formatDateFr(_selectedDate)}'
                  : _formatDateFr(_selectedDate),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(Icons.edit_calendar_outlined,
                size: 16, color: Colors.grey),
          ]),
        ),
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

    final total = _data?['total'] ?? 0;
    final nbVentes = _data?['nb_ventes'] ?? 0;
    final ticketMoyen = _data?['ticket_moyen'] ?? 0;
    final ventes = _data?['ventes'] as List? ?? [];
    final topProduits = _data?['top_produits'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryDark, primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white70, size: 32),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total des ventes du jour',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(_fcfa(total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _statCard('$nbVentes', 'Ventes', Icons.receipt_long_outlined,
                const Color(0xFF1565C0)),
            const SizedBox(width: 10),
            _statCard(_fcfa(ticketMoyen), 'Ticket moyen',
                Icons.analytics_outlined, const Color(0xFF0D47A1)),
          ]),
          const SizedBox(height: 20),
          if (topProduits.isNotEmpty) ...[
            const Text('🏆 Produits les plus vendus',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...topProduits.take(5).map((p) => _produitTile(p)),
            const SizedBox(height: 20),
          ],
          Row(children: [
            const Text('📋 Détail des ventes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$nbVentes vente${nbVentes > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, color: primaryDark)),
            ),
          ]),
          const SizedBox(height: 10),
          if (ventes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: const [
                Text('💰', style: TextStyle(fontSize: 40)),
                SizedBox(height: 12),
                Text('Aucune vente ce jour-là',
                    style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ]),
            )
          else
            ...ventes.map((v) => _venteTile(v)),
          if (ventes.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: PopupMenuButton<String>(
                onSelected: _export,
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
                    border: Border.all(color: const Color(0xFF1565C0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ios_share, size: 18, color: Color(0xFF1565C0)),
                      SizedBox(width: 8),
                      Text(
                        'Télécharger / Partager le rapport',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1565C0)),
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

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

  Widget _produitTile(dynamic p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Row(children: [
        const Text('💊', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['nom'] ?? '',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text('Qté vendue : ${p['quantite']}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
        Text(_fcfa(p['montant']),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
      ]),
    );
  }

  Widget _venteTile(dynamic v) {
    final heure = (v['date'] ?? '').toString().split(' ').length > 1
        ? v['date'].toString().split(' ')[1]
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Center(child: Text('🧾', style: TextStyle(fontSize: 16))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Vente #${v['id']}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text(
                '$heure  •  ${v['client'] ?? '—'}  •  ${v['nb_lignes']} produit${(v['nb_lignes'] ?? 0) > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
        Text(_fcfa(v['total']),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
      ]),
    );
  }
}