import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/export_service.dart';
import '../../core/services/permissions_service.dart';
import 'dossier_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://10.0.2.2:8000/",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  List<dynamic> _clients = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  // Stats globales renvoyées par l'API
  int _totalClients = 0;
  int _totalAnimaux = 0;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _loadClients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get("clients/api/");
      final data = res.data;
      setState(() {
        _clients = data['results'] ?? [];
        _filtered = List.from(_clients);
        _totalClients = data['total_clients'] ?? 0;
        _totalAnimaux = data['total_animaux'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur de connexion : $e";
        _loading = false;
      });
    }
  }

  Future<void> _addClient(Map<String, dynamic> data) async {
    try {
      await _dio.post("clients/api/creer/", data: data);
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Client ajouté ✅'), backgroundColor: primary),
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

  Future<void> _updateClient(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put("clients/api/$id/modifier/", data: data);
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Client modifié ✅'), backgroundColor: primary),
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

  Future<void> _deleteClient(int id) async {
    try {
      await _dio.delete("clients/api/$id/supprimer/");
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Client supprimé'), backgroundColor: Colors.orange),
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

  // ── FILTRE LOCAL ──────────────────────────────────────────────────────────

  void _applyFilter() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _clients.where((c) {
        final nom = (c['nom'] ?? '').toString().toLowerCase();
        final tel = (c['telephone'] ?? '').toString().toLowerCase();
        final adr = (c['adresse'] ?? '').toString().toLowerCase();
        return nom.contains(query) ||
            tel.contains(query) ||
            adr.contains(query);
      }).toList();
    });
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  String _initiales(dynamic client) {
    final nom = (client['nom'] ?? '').toString();
    final parts = nom.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nom.isNotEmpty ? nom[0].toUpperCase() : '?';
  }

  int _nbAnimaux(dynamic client) {
    return (client['nb_animaux'] ?? 0) as int;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0),
      body: Column(
        children: [
          _buildAppBar(),
          if (!_loading && _error == null) _buildStats(),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.person_add_alt_1, color: Colors.white),
      ),
    );
  }

  // ── EXPORT PDF/EXCEL ──────────────────────────────────────────────────────

  Future<void> _exportClients(String format) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: primary),
      ),
    );

    try {
      await ExportService.downloadAndShare(
        endpoint:
            format == 'pdf' ? 'clients/export/pdf/' : 'clients/export/excel/',
        filename: format == 'pdf' ? 'clients.pdf' : 'clients.xlsx',
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
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('👥 Clients',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white)),
              Text('Gestion des propriétaires',
                  style: TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_filtered.length} client${_filtered.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _loadClients,
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
        ],
      ),
    );
  }

  // ── STATS ─────────────────────────────────────────────────────────────────

  Widget _buildStats() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        _statChip('$_totalClients', 'Clients', const Color(0xFF2E7D4F)),
        _statDivider(),
        _statChip('$_totalAnimaux', 'Animaux', const Color(0xFF1565C0)),
        _statDivider(),
        _statChip('${_filtered.length}', 'Affichés', const Color(0xFF6A1B9A)),
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

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Rechercher un client, téléphone, adresse...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
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
              onPressed: _loadClients,
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
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('👥', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Aucun client trouvé',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Modifiez votre recherche ou ajoutez un client',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClients,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _filtered.length + 1,
        itemBuilder: (context, i) {
          if (i == _filtered.length) {
            return PermissionsService.canExportClients
                ? _buildExportButton()
                : const SizedBox.shrink();
          }
          return _buildCard(_filtered[i]);
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
          onSelected: _exportClients,
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
                  'Télécharger / Partager la liste',
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

  // ── CARD CLIENT ───────────────────────────────────────────────────────────

  Widget _buildCard(dynamic client) {
    final initiales = _initiales(client);
    final nb = _nbAnimaux(client);

    return GestureDetector(
      onTap: () => _showDetail(client),
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
          // Avatar initiales
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(initiales,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primaryDark)),
            ),
          ),
          const SizedBox(width: 12),
          // Infos
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(client['nom'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(
                [
                  if ((client['telephone'] ?? '').isNotEmpty)
                    client['telephone'],
                  if ((client['adresse'] ?? '').isNotEmpty) client['adresse'],
                ].join(' • '),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          // Nb animaux + chevron
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (nb > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$nb 🐾',
                    style: const TextStyle(fontSize: 10, color: primaryDark)),
              ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ]),
        ]),
      ),
    );
  }

  // ── DETAIL BOTTOM SHEET ───────────────────────────────────────────────────

  void _showDetail(dynamic client) {
    final animaux = (client['animaux'] as List<dynamic>?) ?? [];

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
          // Pill
          Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(_initiales(client),
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: primaryDark)),
            ),
          ),
          const SizedBox(height: 12),
          Text(client['nom'] ?? '',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),

          // Infos
          _infoRow(
              'Téléphone',
              (client['telephone'] ?? '').isNotEmpty
                  ? client['telephone']
                  : '—'),
          _infoRow('Adresse',
              (client['adresse'] ?? '').isNotEmpty ? client['adresse'] : '—'),
          _infoRow('Animaux', '${_nbAnimaux(client)}'),

          // Liste animaux
          if (animaux.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('🐾 Animaux',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 8),
            ...animaux.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    const Icon(Icons.pets, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${a['nom'] ?? ''}  •  ${a['espece'] ?? ''}${(a['race'] ?? '').isNotEmpty ? '  •  ${a['race']}' : ''}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ]),
                )),
          ],

          const SizedBox(height: 20),

          // ✅ Bouton Dossier complet (animaux + consultations + ordonnances)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DossierClientScreen(
                      clientId: client['id'],
                      clientNom: client['nom'] ?? '',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('Voir le dossier complet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Boutons action
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditDialog(client);
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
            // ✅ Bouton Supprimer — Docteur seulement
            if (PermissionsService.canDeleteClient) ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDelete(client);
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
            ],
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

  void _confirmDelete(dynamic client) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce client ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: Text(
            'Voulez-vous vraiment supprimer ${client['nom']} ?\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteClient(client['id']);
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
    final telCtrl = TextEditingController();
    final adresseCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ajouter un client',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nomCtrl, 'Nom complet *', Icons.person_outline),
            const SizedBox(height: 12),
            _dialogField(telCtrl, 'Téléphone', Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 12),
            _dialogField(adresseCtrl, 'Adresse', Icons.location_on_outlined),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nomCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Le nom est obligatoire'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _addClient({
                'nom': nomCtrl.text.trim(),
                'telephone': telCtrl.text.trim(),
                'adresse': adresseCtrl.text.trim(),
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

  void _showEditDialog(dynamic client) {
    final nomCtrl = TextEditingController(text: client['nom'] ?? '');
    final telCtrl = TextEditingController(text: client['telephone'] ?? '');
    final adresseCtrl = TextEditingController(text: client['adresse'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifier le client',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nomCtrl, 'Nom complet *', Icons.person_outline),
            const SizedBox(height: 12),
            _dialogField(telCtrl, 'Téléphone', Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 12),
            _dialogField(adresseCtrl, 'Adresse', Icons.location_on_outlined),
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
              _updateClient(client['id'], {
                'nom': nomCtrl.text.trim(),
                'telephone': telCtrl.text.trim(),
                'adresse': adresseCtrl.text.trim(),
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

  // ── CHAMP DIALOG ──────────────────────────────────────────────────────────

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
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
