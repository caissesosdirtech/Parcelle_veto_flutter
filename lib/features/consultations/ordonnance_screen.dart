import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/export_service.dart';

class OrdonnanceScreen extends StatefulWidget {
  final int consultationId;

  const OrdonnanceScreen({super.key, required this.consultationId});

  @override
  State<OrdonnanceScreen> createState() => _OrdonnanceScreenState();
}

class _OrdonnanceScreenState extends State<OrdonnanceScreen> {
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://10.0.2.2:8000/",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _terminating = false;
  String? _error;

  Map<String, List<dynamic>> _medParFamille = {};

  // ✅ Consultation verrouillée si déjà terminée
  bool get _isTerminee => _data?['consultation']?['statut'] == 'terminee';

  // ── FORMATAGE FCFA ────────────────────────────────────────────────────────
  String _fcfa(num value) {
    final s = value.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio
          .get("consultations/api/${widget.consultationId}/ordonnance/");
      final data = res.data as Map<String, dynamic>;

      final meds = data['medicaments_disponibles'] as List;
      final grouped = <String, List<dynamic>>{};
      for (final m in meds) {
        final famille = m['famille'] as String? ?? 'Autre';
        grouped.putIfAbsent(famille, () => []).add(m);
      }

      setState(() {
        _data = data;
        _medParFamille = grouped;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur : $e";
        _loading = false;
      });
    }
  }

  // ── EXPORT PDF (avec en-tête cabinet, partage natif) ────────────────────

  Future<void> _exportOrdonnance() async {
    final ordonnanceId = _data?['ordonnance_id'];
    if (ordonnanceId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: primary)),
    );

    try {
      await ExportService.downloadAndShare(
        endpoint: 'consultations/consultations/ordonnance/$ordonnanceId/pdf/',
        filename: 'ordonnance_$ordonnanceId.pdf',
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

  Future<void> _ajouterLigne(
      int medicamentId, int quantite, String posologie) async {
    try {
      final ordonnanceId = _data?['ordonnance_id'];
      await _dio.post(
        "consultations/ordonnance/$ordonnanceId/ajouter-ligne/",
        data: {
          "medicament_id": medicamentId,
          "quantite": quantite,
          "posologie": posologie,
        },
      );
      await _load();
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

  Future<void> _supprimerLigne(int ligneId) async {
    try {
      await _dio.post(
        "consultations/ordonnance/ligne/$ligneId/supprimer/",
        data: {},
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ligne supprimée'), backgroundColor: Colors.orange),
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

  // ── TERMINER CONSULTATION ─────────────────────────────────────────────────

  Future<void> _terminerConsultation() async {
    setState(() => _terminating = true);
    try {
      final res = await _dio.post(
        "consultations/api/${widget.consultationId}/terminer/",
      );

      if (!mounted) return;
      setState(() => _terminating = false);

      final vente = res.data;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Consultation terminée ✅\nVente créée : ${_fcfa(vente['total_vente'] ?? 0)}',
          ),
          backgroundColor: primary,
          duration: const Duration(seconds: 3),
        ),
      );

      // Retour à l'écran précédent (liste consultations)
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _terminating = false);

      final errorData = e.response?.data;
      final message = errorData is Map
          ? (errorData['error'] ?? 'Erreur inconnue')
          : 'Erreur de connexion';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _terminating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmTerminerConsultation() {
    final lignes = _data?['lignes'] as List? ?? [];

    if (lignes.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Text('Ordonnance vide',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ]),
          content: const Text(
            'Vous devez ajouter au moins un médicament à l\'ordonnance avant de terminer la consultation.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
      return;
    }

    // Calcul total prévisionnel
    double total = 0;
    for (final l in lignes) {
      final qte = l['quantite'] ?? 0;
      final med = (_data!['medicaments_disponibles'] as List).firstWhere(
        (m) => m['id'] == l['medicament_id'],
        orElse: () => {'prix': 0},
      );
      total += (qte * (med['prix'] ?? 0));
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: const [
          Icon(Icons.check_circle_outline, color: primary, size: 22),
          SizedBox(width: 8),
          Text('Terminer la consultation ?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette action va :',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _bulletPoint('Créer une vente liée à cette ordonnance'),
            _bulletPoint('Déduire automatiquement le stock des médicaments'),
            _bulletPoint('Marquer la consultation comme terminée'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC8E6C9), width: 0.5),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_long, color: primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total de la vente : ${_fcfa(total)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryDark),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cette action est irréversible.',
              style: TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _terminerConsultation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.circle, size: 5, color: primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ),
      ]),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0),
      body: Column(children: [
        _buildAppBar(),
        Expanded(child: _buildBody()),
      ]),
      bottomNavigationBar:
          _data != null && !_loading && !_isTerminee ? _buildBottomBar() : null,
      floatingActionButton: _data != null && !_isTerminee
          ? FloatingActionButton(
              onPressed: _showAddLigneDialog,
              backgroundColor: const Color(0xFF1565C0),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  // ── APPBAR ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final consult = _data?['consultation'];
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
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📋 Ordonnance',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
            if (consult != null)
              Text('${consult['animal']} — ${consult['client']}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ),
        GestureDetector(
          onTap: _load,
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

  // ── BODY ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: primary));
    }

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
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
      );
    }

    final consult = _data!['consultation'];
    final lignes = _data!['lignes'] as List;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ✅ Bandeau lecture seule si consultation terminée
        if (_isTerminee) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF90CAF9), width: 0.5),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline, color: Color(0xFF1565C0), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Consultation terminée — ordonnance verrouillée (lecture seule)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1565C0)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pets, color: primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${consult['animal']}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('${consult['espece']} · ${consult['client']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
              ),
              Text(consult['date'] ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _infoRow('Motif', consult['motif'] ?? '—'),
          ]),
        ),

        const SizedBox(height: 20),

        Row(children: [
          const Text('💊 Médicaments prescrits',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${lignes.length} ligne${lignes.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: primaryDark)),
          ),
        ]),
        const SizedBox(height: 10),

        if (lignes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
            ),
            child: const Column(children: [
              Text('💊', style: TextStyle(fontSize: 36)),
              SizedBox(height: 10),
              Text('Aucun médicament prescrit',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text('Appuyez sur le bouton + pour ajouter',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          )
        else
          ...lignes.map((l) => _buildLigneTile(l)),

        // ✅ Bouton export PDF avec icône, sous le tableau des médicaments
        if (lignes.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _exportOrdonnance,
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Télécharger / Partager l\'ordonnance'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
                side: const BorderSide(color: Color(0xFF1565C0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  // ── BOTTOM BAR : Bouton Terminer ─────────────────────────────────────────

  Widget _buildBottomBar() {
    final lignes = _data!['lignes'] as List;
    final meds = _data?['medicaments_disponibles'] as List? ?? [];

    double total = 0;
    for (final l in lignes) {
      final med = meds.firstWhere(
        (m) => m['id'] == l['medicament_id'],
        orElse: () => {'prix': 0},
      );
      total += (l['quantite'] ?? 0) * (med['prix'] ?? 0);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lignes.isNotEmpty) ...[
              Row(children: [
                const Text('Total ordonnance',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const Spacer(),
                Text(_fcfa(total),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryDark)),
              ]),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _terminating ? null : _confirmTerminerConsultation,
                icon: _terminating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  _terminating
                      ? 'Traitement en cours...'
                      : 'Terminer la consultation',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primary.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── LIGNE MÉDICAMENT ──────────────────────────────────────────────────────

  Widget _buildLigneTile(dynamic ligne) {
    // Récupérer le prix du médicament pour calculer le sous-total
    final meds = _data?['medicaments_disponibles'] as List? ?? [];
    final med = meds.firstWhere(
      (m) => m['id'] == ligne['medicament_id'],
      orElse: () => {'prix': 0},
    );
    final prixUnitaire = (med['prix'] ?? 0) as num;
    final quantite = (ligne['quantite'] ?? 0) as num;
    final sousTotal = prixUnitaire * quantite;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              const Center(child: Text('💊', style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ligne['medicament_nom'] ?? '',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(ligne['famille'] ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(children: [
              _badge('Qté : ${ligne['quantite']}', const Color(0xFFE3F2FD),
                  const Color(0xFF1565C0)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(ligne['posologie'] ?? '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              '${_fcfa(prixUnitaire)} × $quantite = ${_fcfa(sousTotal)}',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: primary),
            ),
          ]),
        ),
        // ✅ Bouton supprimer caché si consultation terminée
        if (!_isTerminee)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _confirmSupprimerLigne(ligne),
          ),
      ]),
    );
  }

  Widget _badge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, color: textColor, fontWeight: FontWeight.w500)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      const Spacer(),
      Flexible(
        child: Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right),
      ),
    ]);
  }

  // ── CONFIRMER SUPPRESSION LIGNE ───────────────────────────────────────────

  void _confirmSupprimerLigne(dynamic ligne) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer cette ligne ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: Text('Retirer ${ligne['medicament_nom']} de l\'ordonnance ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _supprimerLigne(ligne['id']);
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

  // ── DIALOG AJOUT LIGNE ────────────────────────────────────────────────────

  void _showAddLigneDialog() {
    dynamic selectedMed;
    String? selectedFamille;
    final quantiteCtrl = TextEditingController(text: '1');
    final posologieCtrl = TextEditingController();
    final familles = _medParFamille.keys.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Ajouter un médicament',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('1. Famille',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey))),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedFamille,
                  isExpanded: true,
                  hint: const Text('Choisir une famille',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  items: familles
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Row(children: [
                              const Icon(Icons.category_outlined,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(f),
                              const Spacer(),
                              Text('${(_medParFamille[f] ?? []).length} méd.',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ]),
                          ))
                      .toList(),
                  onChanged: (v) => setSheet(() {
                    selectedFamille = v;
                    selectedMed = null;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('2. Médicament',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey))),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: selectedFamille == null
                    ? const Color(0xFFF0F0F0)
                    : const Color(0xFFF8F8F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<dynamic>(
                  value: selectedMed,
                  isExpanded: true,
                  hint: Text(
                    selectedFamille == null
                        ? 'Choisir d\'abord une famille'
                        : 'Choisir un médicament',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  items: selectedFamille == null
                      ? []
                      : (_medParFamille[selectedFamille] ?? [])
                          .map<DropdownMenuItem<dynamic>>((m) {
                          return DropdownMenuItem<dynamic>(
                            value: m,
                            child: Row(children: [
                              const Text('💊', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m['nom'] ?? '',
                                        style: const TextStyle(fontSize: 13)),
                                    Text(_fcfa(m['prix'] ?? 0),
                                        style: const TextStyle(
                                            fontSize: 10, color: primary)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: m['stock'] <= 5
                                      ? const Color(0xFFFFF3E0)
                                      : const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${m['stock']} u.',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: m['stock'] <= 5
                                            ? const Color(0xFFE65100)
                                            : primary)),
                              ),
                            ]),
                          );
                        }).toList(),
                  onChanged: selectedFamille == null
                      ? null
                      : (v) => setSheet(() => selectedMed = v),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                flex: 2,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('3. Quantité',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: quantiteCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8F8F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFDDDDDD), width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFDDDDDD), width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: primary, width: 1.5),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          suffixText: 'unité(s)',
                          suffixStyle:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('4. Posologie',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: posologieCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'ex: 2x/jour pendant 7j',
                          hintStyle:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFFF8F8F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFDDDDDD), width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFDDDDDD), width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                        ),
                      ),
                    ]),
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (selectedMed == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Veuillez sélectionner un médicament'),
                          backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  if (posologieCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Veuillez indiquer la posologie'),
                          backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _ajouterLigne(
                    selectedMed['id'],
                    int.tryParse(quantiteCtrl.text) ?? 1,
                    posologieCtrl.text.trim(),
                  );
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Ajouter à l\'ordonnance',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
