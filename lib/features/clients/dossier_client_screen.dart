import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../consultations/ordonnance_screen.dart';

class DossierClientScreen extends StatefulWidget {
  final int clientId;
  final String clientNom;

  const DossierClientScreen({
    super.key,
    required this.clientId,
    required this.clientNom,
  });

  @override
  State<DossierClientScreen> createState() => _DossierClientScreenState();
}

class _DossierClientScreenState extends State<DossierClientScreen> {
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://10.0.2.2:8000/",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  // Suit quel animal est déplié (par id)
  final Set<int> _expandedAnimaux = {};

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
      final res = await _dio.get("clients/api/${widget.clientId}/dossier/");
      setState(() {
        _data = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur : $e";
        _loading = false;
      });
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  String _getEmoji(String espece) {
    final e = espece.toLowerCase();
    if (e.contains('chien') || e.contains('dog')) return '🐶';
    if (e.contains('chat') || e.contains('cat')) return '🐱';
    if (e.contains('lapin')) return '🐰';
    if (e.contains('oiseau') || e.contains('perroquet')) return '🦜';
    if (e.contains('reptile') || e.contains('serpent')) return '🦎';
    return '🐾';
  }

  Color _statutConsultColor(String s) {
    switch (s) {
      case 'en_cours':
        return const Color(0xFF1565C0);
      case 'terminee':
        return const Color(0xFF2E7D4F);
      case 'annulee':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _statutConsultBg(String s) {
    switch (s) {
      case 'en_cours':
        return const Color(0xFFE3F2FD);
      case 'terminee':
        return const Color(0xFFE8F5E9);
      case 'annulee':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  String _statutConsultLabel(String s) {
    switch (s) {
      case 'en_cours':
        return 'En cours';
      case 'terminee':
        return 'Terminée';
      case 'annulee':
        return 'Annulée';
      default:
        return s;
    }
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
    );
  }

  // ── APPBAR ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final client = _data?['client'];
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
            const Text('📁 Dossier client',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
            Text(client?['nom'] ?? widget.clientNom,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
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

    final client = _data!['client'];
    final animaux = _data!['animaux'] as List;
    final prochainsRdv = _data!['prochains_rdv'] as List;
    final totalAnimaux = _data!['total_animaux'] ?? 0;
    final totalConsultations = _data!['total_consultations'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ── FICHE CLIENT ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6)
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person, color: primary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client['nom'] ?? '',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        if ((client['telephone'] ?? '').isNotEmpty)
                          Text(client['telephone'],
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                      ]),
                ),
              ]),
              if ((client['adresse'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(client['adresse'],
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ]),
              ],
            ]),
          ),

          const SizedBox(height: 12),

          // ── STATS RAPIDES ────────────────────────────────────────────
          Row(children: [
            _statChip('$totalAnimaux', 'Animaux', Icons.pets, primary),
            const SizedBox(width: 10),
            _statChip('$totalConsultations', 'Consultations',
                Icons.medical_services_outlined, const Color(0xFF1565C0)),
            const SizedBox(width: 10),
            _statChip('${prochainsRdv.length}', 'RDV à venir',
                Icons.calendar_today_outlined, const Color(0xFF6A1B9A)),
          ]),

          const SizedBox(height: 20),

          // ── PROCHAINS RDV ────────────────────────────────────────────
          if (prochainsRdv.isNotEmpty) ...[
            const Text('📅 Prochains rendez-vous',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...prochainsRdv.map((r) => _rdvTile(r)),
            const SizedBox(height: 20),
          ],

          // ── ANIMAUX ──────────────────────────────────────────────────
          const Text('🐾 Animaux & historique médical',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          if (animaux.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🐾', style: TextStyle(fontSize: 36)),
                SizedBox(height: 10),
                Text('Aucun animal enregistré',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            )
          else
            ...animaux.map((a) => _animalCard(a)),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _rdvTile(dynamic r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1BEE7), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.event, size: 18, color: Color(0xFF6A1B9A)),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['animal']} — ${r['motif']}',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(r['date_rdv'],
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      ]),
    );
  }

  // ── CARD ANIMAL (expandable) ─────────────────────────────────────────────

  Widget _animalCard(dynamic animal) {
    final id = animal['id'] as int;
    final isExpanded = _expandedAnimaux.contains(id);
    final consultations = animal['consultations'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // En-tête animal (cliquable)
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedAnimaux.remove(id);
            } else {
              _expandedAnimaux.add(id);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: Text(_getEmoji(animal['espece'] ?? ''),
                        style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(animal['nom'] ?? '',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(
                        [
                          animal['espece'],
                          if ((animal['race'] ?? '').isNotEmpty) animal['race'],
                          if ((animal['poids'] ?? 0) > 0)
                            '${animal['poids']} kg',
                        ].join(' • '),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${consultations.length} consult.',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF1565C0))),
              ),
              const SizedBox(width: 6),
              Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey, size: 22),
            ]),
          ),
        ),

        // Liste consultations (dépliée)
        if (isExpanded) ...[
          const Divider(height: 1),
          if (consultations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune consultation enregistrée',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: consultations
                    .map<Widget>((c) => _consultationTile(c))
                    .toList(),
              ),
            ),
        ],
      ]),
    );
  }

  // ── TILE CONSULTATION (avec ordonnance) ──────────────────────────────────

  Widget _consultationTile(dynamic c) {
    final statut = c['statut'] ?? 'en_cours';
    final lignesOrdo = c['lignes_ordonnance'] as List;
    final ordonnanceId = c['ordonnance_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(c['motif'] ?? '',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _statutConsultBg(statut),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_statutConsultLabel(statut),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: _statutConsultColor(statut))),
          ),
        ]),
        const SizedBox(height: 4),
        Text(c['date'] ?? '',
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        if (lignesOrdo.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          const Text('💊 Ordonnance',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: primary)),
          const SizedBox(height: 4),
          ...lignesOrdo.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• ${l['medicament']} (×${l['quantite']}) — ${l['posologie']}',
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              )),
        ],
        if (ordonnanceId != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrdonnanceScreen(consultationId: c['id']),
                ),
              ).then((_) => _loadData());
            },
            child: Row(children: const [
              Icon(Icons.description_outlined,
                  size: 13, color: Color(0xFF1565C0)),
              SizedBox(width: 4),
              Text('Voir l\'ordonnance complète',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline)),
            ]),
          ),
        ],
      ]),
    );
  }
}
