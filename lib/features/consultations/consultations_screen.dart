import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/permissions_service.dart';
import 'ordonnance_screen.dart';

class ConsultationsScreen extends StatefulWidget {
  const ConsultationsScreen({super.key});

  @override
  State<ConsultationsScreen> createState() => _ConsultationsScreenState();
}

class _ConsultationsScreenState extends State<ConsultationsScreen>
    with SingleTickerProviderStateMixin {
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

  // ── Référentiel Espèces / Races (identique au dict RACES côté Django) ─────
  static const Map<String, List<String>> _races = {
    "Chien": [
      "Chien local",
      "Berger allemand",
      "Berger belge Malinois",
      "Labrador",
      "Rottweiler",
      "Husky",
      "Caniche",
      "Autre"
    ],
    "Chat": ["Siamois", "Persan", "Maine Coon", "Bengal", "Autre"],
    "Bovin": [
      "Gobra",
      "Maure",
      "Djiakoré",
      "N'dama",
      "Zébu",
      "Holstein",
      "Autre"
    ],
    "Caprin": [
      "Chèvre du Sahel",
      "Chèvre naine d'Afrique de l'Ouest",
      "Chèvre rousse de Maradi",
      "Boer",
      "Alpine",
      "Autre"
    ],
    "Ovin": [
      "Ladoum",
      "Mouton Peul-Peul",
      "Touabir",
      "Mérinos",
      "Suffolk",
      "Autre"
    ],
    "Volaille": [
      "Poulet local",
      "Poulet de chair (Broiler)",
      "Pondeuse",
      "Oie",
      "Dinde",
      "Canard",
      "Pintade",
      "Autre"
    ],
    "Cheval": [
      "M'bayar",
      "Cheval du fleuve",
      "Barbe",
      "Pur-sang arabe",
      "Autre"
    ],
    "Poisson": ["Tilapia", "Silure", "Autre"],
    "Autre": ["Autre"],
  };

  static const Map<String, String> _especeEmoji = {
    "Chien": "🐕",
    "Chat": "🐈",
    "Bovin": "🐄",
    "Caprin": "🐐",
    "Ovin": "🐑",
    "Volaille": "🐓",
    "Cheval": "🐴",
    "Poisson": "🐟",
    "Autre": "❓",
  };

  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://10.0.2.2:8000/",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  late TabController _tabCtrl;

  List<dynamic> _consultations = [];
  List<dynamic> _rdvs = [];
  List<dynamic> _animaux = [];
  List<dynamic> _clients = [];
  bool _loading = true;
  String? _error;

  String _filtreStatutConsult = 'Tous';
  String _filtreStatutRdv = 'Tous';

  final _statutsConsult = ['Tous', 'en_cours', 'terminee', 'annulee'];
  final _statutsRdv = ['Tous', 'EN_ATTENTE', 'CONFIRME', 'TERMINE', 'ANNULE'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resC = await _dio.get("consultations/api/liste/");
      final resR = await _dio.get("consultations/api/rdv/");
      final resA = await _dio.get("animaux/api/liste/");
      final resCl = await _dio.get("clients/api/");
      setState(() {
        _consultations = resC.data is List ? resC.data : [];
        _rdvs = resR.data is List ? resR.data : [];
        _animaux = resA.data is List ? resA.data : (resA.data['results'] ?? []);
        _clients =
            resCl.data is List ? resCl.data : (resCl.data['results'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur : $e";
        _loading = false;
      });
    }
  }

  Future<void> _ajouterConsultation(Map<String, dynamic> data) async {
    try {
      // ✅ Utilise la route Django existante create_consultation,
      //    qui gère les 3 modes : existing / existing_new_animal / new
      await _dio.post("consultations/nouvelle/save/", data: data);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Consultation créée ✅'), backgroundColor: primary),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = 'Erreur : $e';
        if (e is DioException && e.response?.data is Map) {
          message = e.response!.data['error']?.toString() ?? message;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _changerStatutConsult(int id, String statut) async {
    try {
      await _dio.put("consultations/api/$id/statut/", data: {"statut": statut});
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _ajouterRdv(Map<String, dynamic> data) async {
    try {
      await _dio.post("consultations/api/rdv/ajouter/", data: data);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('RDV ajouté ✅'), backgroundColor: primary),
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

  Future<void> _changerStatutRdv(int id, String type, String statut) async {
    try {
      await _dio.put(
        "consultations/api/rdv/$id/statut/",
        data: {"type": type, "statut": statut},
      );
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  List<dynamic> get _consultationsFiltrees {
    if (_filtreStatutConsult == 'Tous') return _consultations;
    return _consultations
        .where((c) => c['statut'] == _filtreStatutConsult)
        .toList();
  }

  List<dynamic> get _rdvsFiltres {
    if (_filtreStatutRdv == 'Tous') return _rdvs;
    return _rdvs.where((r) => r['statut'] == _filtreStatutRdv).toList();
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

  Color _statutRdvColor(String s) {
    switch (s) {
      case 'EN_ATTENTE':
        return const Color(0xFFE65100);
      case 'CONFIRME':
        return const Color(0xFF2E7D4F);
      case 'TERMINE':
        return Colors.grey;
      case 'ANNULE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _statutRdvBg(String s) {
    switch (s) {
      case 'EN_ATTENTE':
        return const Color(0xFFFFF3E0);
      case 'CONFIRME':
        return const Color(0xFFE8F5E9);
      case 'TERMINE':
        return const Color(0xFFF5F5F5);
      case 'ANNULE':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  String _statutRdvLabel(String s) {
    switch (s) {
      case 'EN_ATTENTE':
        return 'En attente';
      case 'CONFIRME':
        return 'Confirmé';
      case 'TERMINE':
        return 'Terminé';
      case 'ANNULE':
        return 'Annulé';
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
        _buildTabs(),
        Expanded(child: _buildBody()),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabCtrl.index == 0) {
            _showAddConsultationDialog();
          } else {
            _showAddRdvDialog();
          }
        },
        backgroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white),
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
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
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
          Text('📅 Consultations & RDV',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          Text('Suivi des consultations et rendez-vous',
              style: TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: _loadAll,
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

  // ── TABS ──────────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDark, primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: [
          Tab(text: 'Consultations (${_consultations.length})'),
          Tab(text: 'RDV (${_rdvs.length})'),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadAll,
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

    return TabBarView(
      controller: _tabCtrl,
      children: [_buildConsultationsTab(), _buildRdvsTab()],
    );
  }

  // ── ONGLET CONSULTATIONS ──────────────────────────────────────────────────

  Widget _buildConsultationsTab() {
    return Column(children: [
      _buildFiltreBar(_statutsConsult, _filtreStatutConsult, (v) {
        setState(() => _filtreStatutConsult = v);
      }),
      Expanded(
        child: _consultationsFiltrees.isEmpty
            ? _buildEmpty('Aucune consultation',
                'Appuyez sur + pour créer une consultation')
            : RefreshIndicator(
                onRefresh: _loadAll,
                color: primary,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: _consultationsFiltrees.length,
                  itemBuilder: (_, i) =>
                      _buildConsultCard(_consultationsFiltrees[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _buildConsultCard(dynamic c) {
    final statut = c['statut'] ?? 'en_cours';
    return GestureDetector(
      onTap: () => _showConsultDetail(c),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.medical_services_outlined,
                  color: Color(0xFF1565C0), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c['animal'] ?? ''} — ${c['client'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(c['espece'] ?? '',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statutConsultBg(statut),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_statutConsultLabel(statut),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _statutConsultColor(statut))),
            ),
          ]),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.notes_outlined, size: 13, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(c['motif'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Text(c['date'] ?? '',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }

  // ── ONGLET RDV ────────────────────────────────────────────────────────────

  Widget _buildRdvsTab() {
    return Column(children: [
      _buildFiltreBar(_statutsRdv, _filtreStatutRdv, (v) {
        setState(() => _filtreStatutRdv = v);
      }),
      Expanded(
        child: _rdvsFiltres.isEmpty
            ? _buildEmpty(
                'Aucun rendez-vous', 'Appuyez sur + pour créer un RDV')
            : RefreshIndicator(
                onRefresh: _loadAll,
                color: primary,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: _rdvsFiltres.length,
                  itemBuilder: (_, i) => _buildRdvCard(_rdvsFiltres[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _buildRdvCard(dynamic r) {
    final statut = r['statut'] ?? 'EN_ATTENTE';
    final isManuel = r['type'] == 'manuel';
    return GestureDetector(
      onTap: () => _showRdvDetail(r),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                r['type_rdv'] == 'DOMICILE' || r['type_rdv'] == 'domicile'
                    ? Icons.home_outlined
                    : Icons.local_hospital_outlined,
                color: const Color(0xFF6A1B9A),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                            '${r['animal'] ?? ''} — ${r['client'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      if (isManuel)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Manuel',
                              style: TextStyle(
                                  fontSize: 9, color: Color(0xFF1565C0))),
                        ),
                    ]),
                    Text(r['espece'] ?? '',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statutRdvBg(statut),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_statutRdvLabel(statut),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _statutRdvColor(statut))),
            ),
          ]),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.access_time_outlined,
                size: 13, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(r['date_rdv'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const Icon(Icons.notes_outlined, size: 13, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(r['motif'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── FILTRE BAR ────────────────────────────────────────────────────────────

  Widget _buildFiltreBar(
      List<String> statuts, String selected, Function(String) onTap) {
    final labels = {
      'Tous': 'Tous',
      'en_cours': 'En cours',
      'terminee': 'Terminées',
      'annulee': 'Annulées',
      'EN_ATTENTE': 'En attente',
      'CONFIRME': 'Confirmés',
      'TERMINE': 'Terminés',
      'ANNULE': 'Annulés',
    };
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: statuts.map((s) {
            final isSelected = selected == s;
            return GestureDetector(
              onTap: () => onTap(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.white,
                  border: Border.all(
                      color: isSelected ? primary : const Color(0xFFDDDDDD)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(labels[s] ?? s,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey[600])),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── DETAIL CONSULTATION ───────────────────────────────────────────────────

  void _showConsultDetail(dynamic c) {
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
          const Icon(Icons.medical_services_outlined,
              size: 40, color: Color(0xFF1565C0)),
          const SizedBox(height: 10),
          Text('${c['animal'] ?? ''} — ${c['client'] ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statutConsultBg(c['statut'] ?? ''),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_statutConsultLabel(c['statut'] ?? ''),
                style: TextStyle(
                    fontSize: 12,
                    color: _statutConsultColor(c['statut'] ?? ''))),
          ),
          const SizedBox(height: 20),
          _infoRow('Motif', c['motif'] ?? '—'),
          _infoRow('Observations',
              (c['observations'] ?? '').isNotEmpty ? c['observations'] : '—'),
          _infoRow('Vétérinaire',
              (c['veterinaire'] ?? '').isNotEmpty ? c['veterinaire'] : '—'),
          _infoRow('Lieu', c['lieu'] == 'domicile' ? 'Domicile' : 'Cabinet'),
          _infoRow('Poids', (c['poids'] ?? 0) > 0 ? '${c['poids']} kg' : '—'),
          _infoRow('Date', c['date'] ?? '—'),
          const SizedBox(height: 20),

          // ✅ Bouton Ordonnance — Docteur seulement
          if (PermissionsService.canGererOrdonnance) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrdonnanceScreen(consultationId: c['id']),
                    ),
                  ).then((_) => _loadAll());
                },
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Voir / Créer l\'ordonnance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ✅ Actions statut — Docteur seulement
          if (PermissionsService.canTerminerConsultation &&
              c['statut'] == 'en_cours') ...[
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _changerStatutConsult(c['id'], 'terminee');
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Terminer'),
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
                    _changerStatutConsult(c['id'], 'annulee');
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Annuler'),
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
          ],
        ]),
      ),
    );
  }

  // ── DETAIL RDV ────────────────────────────────────────────────────────────

  void _showRdvDetail(dynamic r) {
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
          Icon(
            r['type_rdv'] == 'DOMICILE' || r['type_rdv'] == 'domicile'
                ? Icons.home_outlined
                : Icons.local_hospital_outlined,
            size: 40,
            color: const Color(0xFF6A1B9A),
          ),
          const SizedBox(height: 10),
          Text('${r['animal'] ?? ''} — ${r['client'] ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statutRdvBg(r['statut'] ?? ''),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_statutRdvLabel(r['statut'] ?? ''),
                style: TextStyle(
                    fontSize: 12, color: _statutRdvColor(r['statut'] ?? ''))),
          ),
          const SizedBox(height: 20),
          _infoRow('Date', r['date_rdv'] ?? '—'),
          _infoRow('Motif', r['motif'] ?? '—'),
          _infoRow('Lieu', r['lieu'] ?? '—'),
          if ((r['telephone'] ?? '').isNotEmpty)
            _infoRow('Téléphone', r['telephone']),
          const SizedBox(height: 20),
          if (r['statut'] == 'EN_ATTENTE') ...[
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _changerStatutRdv(r['id'], r['type'], 'CONFIRME');
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Confirmer'),
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
                    _changerStatutRdv(r['id'], r['type'], 'ANNULE');
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Annuler'),
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
          ],
          if (r['statut'] == 'CONFIRME') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _changerStatutRdv(r['id'], r['type'], 'TERMINE');
                },
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Marquer comme terminé'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
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
        Flexible(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right),
        ),
      ]),
    );
  }

  // ── DIALOG AJOUT CONSULTATION ─────────────────────────────────────────────

  void _showAddConsultationDialog() {
    final motifCtrl = TextEditingController();
    final observationsCtrl = TextEditingController();
    final poidsConsultCtrl = TextEditingController();
    String selectedLieu = 'cabinet';

    // ── Mode de sélection ────────────────────────────────────────────
    // 'existing'            : animal déjà connu (client + animal en base)
    // 'existing_new_animal' : client connu, nouvel animal pour lui
    // 'new'                 : nouveau client ET nouvel animal
    String mode = 'existing';

    dynamic selectedAnimal; // pour mode == existing
    dynamic selectedClient; // pour mode == existing_new_animal

    // Champs nouveau client (mode == new)
    final clientNomCtrl = TextEditingController();
    final clientPhoneCtrl = TextEditingController();
    final clientAdresseCtrl = TextEditingController();

    // Champs nouvel animal (mode == existing_new_animal OU new)
    final animalNomCtrl = TextEditingController();
    final animalPoidsCtrl = TextEditingController();
    String animalSexe = 'M';

    // ✅ Espèce / Race en dropdown cascade (remplace les TextEditingController)
    String? selectedEspece;
    String? selectedRace;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouvelle consultation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Sélecteur de mode (3 options) ────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(children: [
                  _modeOption(
                    label: '🐾 Animal déjà enregistré',
                    selected: mode == 'existing',
                    onTap: () => setDialog(() => mode = 'existing'),
                  ),
                  _modeOption(
                    label: '👤 Client connu, nouvel animal',
                    selected: mode == 'existing_new_animal',
                    onTap: () => setDialog(() => mode = 'existing_new_animal'),
                  ),
                  _modeOption(
                    label: '✨ Nouveau client',
                    selected: mode == 'new',
                    onTap: () => setDialog(() => mode = 'new'),
                  ),
                ]),
              ),

              const SizedBox(height: 14),

              // ══════════ MODE 1 : Animal existant ══════════
              if (mode == 'existing') ...[
                if (_animaux.isEmpty)
                  _emptyHint(
                      'Aucun animal enregistré. Choisissez une autre option.')
                else
                  _dropdownContainer(
                    child: DropdownButton<dynamic>(
                      value: selectedAnimal,
                      isExpanded: true,
                      hint: const Text('Sélectionner un animal *',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87),
                      items: _animaux.map<DropdownMenuItem<dynamic>>((a) {
                        return DropdownMenuItem<dynamic>(
                          value: a,
                          child: Text('${a['nom']} (${a['client']})',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) => setDialog(() => selectedAnimal = v),
                    ),
                  ),
              ],

              // ══════════ MODE 2 : Client connu, nouvel animal ══════════
              if (mode == 'existing_new_animal') ...[
                if (_clients.isEmpty)
                  _emptyHint(
                      'Aucun client enregistré. Choisissez "Nouveau client".')
                else
                  _dropdownContainer(
                    child: DropdownButton<dynamic>(
                      value: selectedClient,
                      isExpanded: true,
                      hint: const Text('Sélectionner un client *',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87),
                      items: _clients.map<DropdownMenuItem<dynamic>>((c) {
                        return DropdownMenuItem<dynamic>(
                          value: c,
                          child: Text(c['nom'] ?? '',
                              style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (v) => setDialog(() => selectedClient = v),
                    ),
                  ),
                const SizedBox(height: 12),
                _dialogField(animalNomCtrl, 'Nom animal', Icons.pets_outlined),
                const SizedBox(height: 12),
                // ✅ Dropdowns Espèce → Race en cascade
                _especeRaceDropdowns(
                  selectedEspece: selectedEspece,
                  selectedRace: selectedRace,
                  onEspeceChanged: (v) => setDialog(() {
                    selectedEspece = v;
                    selectedRace = null;
                  }),
                  onRaceChanged: (v) => setDialog(() => selectedRace = v),
                ),
                const SizedBox(height: 12),
                _sexeDropdown(
                    animalSexe, (v) => setDialog(() => animalSexe = v)),
                const SizedBox(height: 12),
                _dialogField(animalPoidsCtrl, 'Poids animal (kg)',
                    Icons.monitor_weight_outlined,
                    type: TextInputType.number),
              ],

              // ══════════ MODE 3 : Nouveau client + nouvel animal ══════════
              if (mode == 'new') ...[
                _dialogField(
                    clientNomCtrl, 'Nom client *', Icons.person_outline),
                const SizedBox(height: 12),
                _dialogField(clientPhoneCtrl, 'Téléphone', Icons.phone_outlined,
                    type: TextInputType.phone),
                const SizedBox(height: 12),
                _dialogField(
                    clientAdresseCtrl, 'Adresse', Icons.location_on_outlined),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Animal',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primary)),
                ),
                const SizedBox(height: 8),
                _dialogField(animalNomCtrl, 'Nom animal', Icons.pets_outlined),
                const SizedBox(height: 12),
                // ✅ Dropdowns Espèce → Race en cascade
                _especeRaceDropdowns(
                  selectedEspece: selectedEspece,
                  selectedRace: selectedRace,
                  onEspeceChanged: (v) => setDialog(() {
                    selectedEspece = v;
                    selectedRace = null;
                  }),
                  onRaceChanged: (v) => setDialog(() => selectedRace = v),
                ),
                const SizedBox(height: 12),
                _sexeDropdown(
                    animalSexe, (v) => setDialog(() => animalSexe = v)),
                const SizedBox(height: 12),
                _dialogField(animalPoidsCtrl, 'Poids animal (kg)',
                    Icons.monitor_weight_outlined,
                    type: TextInputType.number),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),

              // ── Champs communs : motif, observations, poids consultation, lieu ──
              _dialogField(motifCtrl, 'Motif *', Icons.notes_outlined),
              const SizedBox(height: 12),
              _dialogField(
                  observationsCtrl, 'Observations', Icons.description_outlined),
              const SizedBox(height: 12),
              _dialogField(poidsConsultCtrl, 'Poids constaté (kg)',
                  Icons.monitor_weight_outlined,
                  type: TextInputType.number),
              const SizedBox(height: 12),
              _dropdownContainer(
                child: DropdownButton<String>(
                  value: selectedLieu,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 'cabinet', child: Text('Cabinet')),
                    DropdownMenuItem(
                        value: 'domicile', child: Text('Domicile')),
                  ],
                  onChanged: (v) => setDialog(() => selectedLieu = v!),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (motifCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Le motif est obligatoire'),
                        backgroundColor: Colors.orange),
                  );
                  return;
                }

                final Map<String, dynamic> payload = {
                  'mode': mode,
                  'motif': motifCtrl.text.trim(),
                  'observations': observationsCtrl.text.trim(),
                  'lieu': selectedLieu,
                  'animal_poids': poidsConsultCtrl.text.trim().isNotEmpty
                      ? poidsConsultCtrl.text.trim()
                      : null,
                };

                if (mode == 'existing') {
                  if (selectedAnimal == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Veuillez sélectionner un animal'),
                          backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  payload['animal_id'] = selectedAnimal['id'];
                  payload['client_id'] = selectedAnimal['client_id'];
                } else if (mode == 'existing_new_animal') {
                  if (selectedClient == null || selectedEspece == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Client et Espèce obligatoires'),
                          backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  payload['client_id'] = selectedClient['id'];
                  payload['animal_nom'] = animalNomCtrl.text.trim();
                  payload['animal_espece'] = selectedEspece;
                  payload['animal_race'] = selectedRace ?? '';
                  payload['animal_sexe'] = animalSexe;
                } else {
                  // mode == 'new'
                  if (clientNomCtrl.text.trim().isEmpty ||
                      selectedEspece == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Nom client et Espèce obligatoires'),
                          backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  payload['client_nom'] = clientNomCtrl.text.trim();
                  payload['client_phone'] = clientPhoneCtrl.text.trim();
                  payload['client_adresse'] = clientAdresseCtrl.text.trim();
                  payload['animal_nom'] = animalNomCtrl.text.trim();
                  payload['animal_espece'] = selectedEspece;
                  payload['animal_race'] = selectedRace ?? '';
                  payload['animal_sexe'] = animalSexe;
                }

                Navigator.pop(context);
                _ajouterConsultation(payload);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  // ── WIDGETS HELPER DU DIALOG ──────────────────────────────────────────────

  Widget _modeOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 16,
            color: selected ? Colors.white : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : Colors.grey[800])),
        ]),
      ),
    );
  }

  Widget _dropdownContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Widget _emptyHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: Color(0xFFE65100))),
    );
  }

  Widget _sexeDropdown(String value, void Function(String) onChanged) {
    return _dropdownContainer(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        items: const [
          DropdownMenuItem(value: 'M', child: Text('Mâle')),
          DropdownMenuItem(value: 'F', child: Text('Femelle')),
        ],
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  // ✅ Dropdown en cascade Espèce → Race (réutilisé dans les 2 dialogs)
  Widget _especeRaceDropdowns({
    required String? selectedEspece,
    required String? selectedRace,
    required void Function(String?) onEspeceChanged,
    required void Function(String?) onRaceChanged,
  }) {
    final racesDisponibles =
        selectedEspece != null ? (_races[selectedEspece] ?? []) : <String>[];

    return Column(children: [
      _dropdownContainer(
        child: DropdownButton<String>(
          value: selectedEspece,
          isExpanded: true,
          hint: const Text('Espèce *',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: _races.keys.map((espece) {
            return DropdownMenuItem<String>(
              value: espece,
              child: Text('${_especeEmoji[espece] ?? ''} $espece',
                  style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: onEspeceChanged,
        ),
      ),
      const SizedBox(height: 12),
      _dropdownContainer(
        child: DropdownButton<String>(
          value: selectedRace,
          isExpanded: true,
          hint: Text(
            selectedEspece == null ? 'Choisir une espèce d\'abord' : 'Race',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: racesDisponibles.map((race) {
            return DropdownMenuItem<String>(
              value: race,
              child: Text(race, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: selectedEspece == null ? null : onRaceChanged,
        ),
      ),
    ]);
  }

  // ── DIALOG AJOUT RDV ──────────────────────────────────────────────────────

  void _showAddRdvDialog() {
    final clientCtrl = TextEditingController();
    final animalCtrl = TextEditingController();
    final motifCtrl = TextEditingController();
    final adresseCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    String selectedLieu = 'cabinet';
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));

    // ✅ Mode sélection : animal existant (par défaut) ou nouveau client
    bool nouveauClient = false;
    dynamic selectedAnimal; // animal choisi depuis _animaux (avec client lié)

    // ✅ Espèce / Race en dropdown cascade pour le mode "nouveau client"
    String? selectedEspeceRdv;
    String? selectedRaceRdv;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouveau RDV',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Bascule client existant / nouveau ──────────────────
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialog(() {
                        nouveauClient = false;
                        selectedAnimal = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !nouveauClient ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Client existant',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: !nouveauClient
                                    ? Colors.white
                                    : Colors.grey[700])),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialog(() {
                        nouveauClient = true;
                        selectedAnimal = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: nouveauClient ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Nouveau client',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: nouveauClient
                                    ? Colors.white
                                    : Colors.grey[700])),
                      ),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 14),

              // ── CAS 1 : Client existant → dropdown animal ──────────
              if (!nouveauClient) ...[
                if (_animaux.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Aucun animal enregistré. Utilisez "Nouveau client".',
                      style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAF8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFDDDDDD), width: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<dynamic>(
                        value: selectedAnimal,
                        isExpanded: true,
                        hint: const Text('Sélectionner client + animal *',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                        items: _animaux.map<DropdownMenuItem<dynamic>>((a) {
                          return DropdownMenuItem<dynamic>(
                            value: a,
                            child: Text(
                              '${a['nom']} (${a['espece']}) — ${a['client']}',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setDialog(() => selectedAnimal = v),
                      ),
                    ),
                  ),

                // Récap visuel une fois l'animal choisi
                if (selectedAnimal != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFC8E6C9), width: 0.5),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle, size: 16, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Client : ${selectedAnimal['client']}',
                          style:
                              const TextStyle(fontSize: 12, color: primaryDark),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],

              // ── CAS 2 : Nouveau client → champs libres ──────────────
              if (nouveauClient) ...[
                _dialogField(clientCtrl, 'Nom client *', Icons.person_outline),
                const SizedBox(height: 12),
                _dialogField(animalCtrl, 'Nom animal', Icons.pets_outlined),
                const SizedBox(height: 12),
                // ✅ Dropdowns Espèce → Race en cascade
                _especeRaceDropdowns(
                  selectedEspece: selectedEspeceRdv,
                  selectedRace: selectedRaceRdv,
                  onEspeceChanged: (v) => setDialog(() {
                    selectedEspeceRdv = v;
                    selectedRaceRdv = null;
                  }),
                  onRaceChanged: (v) => setDialog(() => selectedRaceRdv = v),
                ),
                const SizedBox(height: 12),
                _dialogField(telCtrl, 'Téléphone', Icons.phone_outlined,
                    type: TextInputType.phone),
              ],

              const SizedBox(height: 12),
              _dialogField(motifCtrl, 'Motif *', Icons.notes_outlined),
              const SizedBox(height: 12),

              // Date
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(primary: primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (d != null) setDialog(() => selectedDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAF8),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF8),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLieu,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    items: const [
                      DropdownMenuItem(
                          value: 'cabinet', child: Text('Cabinet')),
                      DropdownMenuItem(
                          value: 'domicile', child: Text('Domicile')),
                    ],
                    onChanged: (v) => setDialog(() => selectedLieu = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _dialogField(adresseCtrl, 'Adresse', Icons.location_on_outlined),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (motifCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Le motif est obligatoire'),
                        backgroundColor: Colors.orange),
                  );
                  return;
                }

                String nomClient;
                String nomAnimal;
                String espece;
                String race;
                String telephone;

                if (!nouveauClient) {
                  if (selectedAnimal == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Veuillez sélectionner un animal'),
                          backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  nomClient = selectedAnimal['client'] ?? '';
                  nomAnimal = selectedAnimal['nom'] ?? '';
                  espece = selectedAnimal['espece'] ?? '';
                  race = selectedAnimal['race'] ?? '';
                  telephone = telCtrl.text.trim();
                } else {
                  if (clientCtrl.text.trim().isEmpty ||
                      selectedEspeceRdv == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Client et Espèce obligatoires'),
                          backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  nomClient = clientCtrl.text.trim();
                  nomAnimal = animalCtrl.text.trim();
                  espece = selectedEspeceRdv!;
                  race = selectedRaceRdv ?? '';
                  telephone = telCtrl.text.trim();
                }

                Navigator.pop(context);
                _ajouterRdv({
                  'nom_client': nomClient,
                  'nom_animal': nomAnimal,
                  'espece': espece,
                  'race': race,
                  'motif': motifCtrl.text.trim(),
                  'telephone': telephone,
                  'adresse': adresseCtrl.text.trim(),
                  'lieu': selectedLieu,
                  'date_rdv': selectedDate.toIso8601String(),
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Créer'),
            ),
          ],
        ),
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

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('📅', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ]),
    );
  }
}
