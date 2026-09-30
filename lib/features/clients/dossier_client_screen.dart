import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
// ⚠️ Ajuste ce chemin si OrdonnanceScreen se trouve ailleurs dans ton projet
// (ex: '../consultations/ordonnance_screen.dart' ou '../ordonnances/ordonnance_screen.dart').
import '../consultations/ordonnance_screen.dart';

class DossierClientScreen extends StatefulWidget {
  final dynamic client;

  const DossierClientScreen({super.key, required this.client});

  @override
  State<DossierClientScreen> createState() => _DossierClientScreenState();
}

class _DossierClientScreenState extends State<DossierClientScreen> {
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  Map<String, dynamic>? _clientInfo;
  List<dynamic> _animaux = [];
  List<dynamic> _prochainsRdv = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDossier();
  }

  // ⚠️ Endpoint corrigé : le dossier complet vit sur "clients/api/<id>/dossier/"
  // (api_dossier_client), pas sur "consultations/clients/<id>/animaux/" qui
  // n'existe pas dans les urls et ne renvoie ni consultations ni RDV ni ordonnances.
  Future<void> _loadDossier() async {
    final clientMap = widget.client is Map<String, dynamic>
        ? widget.client
        : Map<String, dynamic>.from(widget.client);
    final clientId = clientMap['id'];

    if (clientId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _dio.get("clients/api/$clientId/dossier/");
      final data = res.data;

      if (mounted) {
        setState(() {
          _clientInfo = data['client'] is Map ? Map<String, dynamic>.from(data['client']) : clientMap;
          _animaux = data['animaux'] as List<dynamic>? ?? [];
          _prochainsRdv = data['prochains_rdv'] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur chargement dossier client : $e");
      if (mounted) {
        setState(() {
          _clientInfo = clientMap;
          _animaux = clientMap['animaux'] as List<dynamic>? ?? [];
          _prochainsRdv = [];
          _error = "Impossible de charger l'historique complet (RDV/consultations/ordonnances).";
          _loading = false;
        });
      }
    }
  }

  String _initiales(String nom) {
    final parts = nom.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nom.isNotEmpty ? nom[0].toUpperCase() : '?';
  }

  bool _estTerminee(String? statut) {
    final s = (statut ?? '').toLowerCase();
    return s == 'terminee' || s == 'terminée' || s == 'termine';
  }

  void _ouvrirOrdonnance(Map<String, dynamic> consultation) {
    final consultationId = consultation['id'];
    if (consultationId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrdonnanceScreen(
          consultationId: consultationId is int ? consultationId : int.parse(consultationId.toString()),
          ordonnance: consultation,
        ),
      ),
    ).then((_) => _loadDossier()); // rafraîchit au retour, au cas où l'ordonnance a été modifiée
  }

  @override
  Widget build(BuildContext context) {
    final clientMap = widget.client is Map<String, dynamic>
        ? widget.client
        : Map<String, dynamic>.from(widget.client);

    final info = _clientInfo ?? clientMap;
    final String nom = info['nom'] ?? 'Client';
    final String telephone = (info['telephone'] ?? '').toString().isNotEmpty
        ? info['telephone']
        : 'Non renseigné';
    final String adresse = (info['adresse'] ?? '').toString().isNotEmpty
        ? info['adresse']
        : 'Non renseignée';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0),
      appBar: AppBar(
        title: Text(nom, style: const TextStyle(fontSize: 18, color: Colors.white)),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDossier),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
        onRefresh: _loadDossier,
        color: primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFF8A5300), fontSize: 12)),
                ),

              // ── Carte profil client ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFE8F5E9),
                      child: Text(_initiales(nom), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryDark)),
                    ),
                    const SizedBox(height: 12),
                    Text(nom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _infoRow(Icons.phone_outlined, 'Téléphone', telephone),
                    const SizedBox(height: 8),
                    _infoRow(Icons.location_on_outlined, 'Adresse', adresse),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Prochains rendez-vous (tous animaux confondus) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('📅 Prochains rendez-vous', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryDark)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
                    child: Text('${_prochainsRdv.length}', style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_prochainsRdv.isEmpty)
                _emptyBox('Aucun rendez-vous à venir')
              else
                ..._prochainsRdv.map((r) => _rdvTile(r)),

              const SizedBox(height: 20),

              // ── Animaux + historique ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🐾 Animaux & historique médical', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryDark)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                    child: Text('${_animaux.length}', style: const TextStyle(fontSize: 11, color: primaryDark, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_animaux.isEmpty)
                _emptyBox('Aucun animal enregistré pour ce client')
              else
                ..._animaux.map((a) => _animalCard(a as Map<String, dynamic>)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
      ),
      child: Center(child: Text(message, style: const TextStyle(color: Colors.grey, fontSize: 13))),
    );
  }

  Widget _rdvTile(dynamic r) {
    final rMap = r as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.event_outlined, color: Color(0xFF1565C0), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${rMap['date_rdv'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '🐾 ${rMap['animal'] ?? ''} — ${rMap['motif'] ?? 'Non renseigné'}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if ((rMap['statut'] ?? '').toString().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F3), borderRadius: BorderRadius.circular(6)),
              child: Text(rMap['statut'].toString(), style: const TextStyle(fontSize: 10, color: Colors.black87)),
            ),
        ],
      ),
    );
  }

  Widget _animalCard(Map<String, dynamic> animal) {
    final aNom = animal['nom'] ?? 'Sans nom';
    final espece = animal['espece'] ?? '';
    final race = (animal['race'] ?? '').toString();
    final sexe = (animal['sexe'] ?? '').toString();
    final poids = animal['poids'];
    final consultations = animal['consultations'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: const Color(0xFFF5F5F3), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.pets, color: primary, size: 20),
          ),
          title: Text(aNom, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Text(
            [
              if (espece.toString().isNotEmpty) espece,
              if (race.isNotEmpty) race,
              if (sexe.isNotEmpty) (sexe == 'M' ? 'Mâle' : 'Femelle'),
              if (poids != null && poids != 0) '$poids kg',
            ].join(' • '),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          children: [
            if (consultations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucune consultation enregistrée', style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('📋 Consultations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryDark)),
              ),
              const SizedBox(height: 8),
              ...consultations.map((c) => _consultationTile(c as Map<String, dynamic>)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _consultationTile(Map<String, dynamic> c) {
    final bool terminee = _estTerminee(c['statut']?.toString());
    final lignes = c['lignes_ordonnance'] as List<dynamic>? ?? [];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _ouvrirOrdonnance(c),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAF9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEDEDEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c['date'] ?? '',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: terminee ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      terminee ? 'Terminée' : 'En cours',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: terminee ? primaryDark : const Color(0xFF8A5300)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 4),
              Text('Motif : ${c['motif'] ?? 'Non renseigné'}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
              if ((c['observations'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Observations : ${c['observations']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
              if ((c['veterinaire'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Vétérinaire : ${c['veterinaire']}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
              ],

              if (lignes.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFEDEDEA)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('💊 Ordonnance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primary)),
                    const Text('Voir le détail →', style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ...lignes.map((l) {
                  final lMap = l as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 11)),
                        Expanded(
                          child: Text(
                            '${lMap['medicament'] ?? 'Médicament'} (x${lMap['quantite'] ?? 1})'
                                '${(lMap['posologie'] ?? '').toString().isNotEmpty ? ' — ${lMap['posologie']}' : ''}',
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else if (c['ordonnance_id'] != null) ...[
                const SizedBox(height: 6),
                const Text('Ordonnance créée, sans médicament renseigné. Toucher pour compléter →', style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primary),
        const SizedBox(width: 10),
        Text('$label : ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
        ),
      ],
    );
  }
}