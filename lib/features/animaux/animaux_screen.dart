import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class AnimauxScreen extends StatefulWidget {
  const AnimauxScreen({super.key});

  @override
  State<AnimauxScreen> createState() => _AnimauxScreenState();
}

class _AnimauxScreenState extends State<AnimauxScreen> {
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: "http://10.0.2.2:8000/",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  List<dynamic> _animaux = [];
  List<dynamic> _filtered = [];
  List<dynamic> _clients = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'Tous';
  final _searchCtrl = TextEditingController();

  final _filters = ['Tous', 'Chien', 'Chat', 'Lapin', 'Autre'];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resAnimaux = await _dio.get("animaux/api/liste/");
      final resClients = await _dio.get("clients/api/");
      setState(() {
        _animaux = resAnimaux.data is List
            ? resAnimaux.data
            : (resAnimaux.data['results'] ?? []);
        _clients = resClients.data is List
            ? resClients.data
            : (resClients.data['results'] ?? []);
        _filtered = List.from(_animaux);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur : $e";
        _loading = false;
      });
    }
  }

  Future<void> _ajouterAnimal(Map<String, dynamic> data) async {
    try {
      await _dio.post("animaux/api/ajouter/", data: data);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Animal ajouté ✅'), backgroundColor: primary),
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

  Future<void> _modifierAnimal(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put("animaux/api/$id/modifier/", data: data);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Animal modifié ✅'), backgroundColor: primary),
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

  Future<void> _supprimerAnimal(int id) async {
    try {
      await _dio.delete("animaux/api/$id/supprimer/");
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Animal supprimé'), backgroundColor: Colors.orange),
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

  // ── FILTRES ───────────────────────────────────────────────────────────────

  void _applyFilter() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _animaux.where((a) {
        final matchSearch =
            (a['nom'] ?? '').toString().toLowerCase().contains(query) ||
                (a['client'] ?? '').toString().toLowerCase().contains(query) ||
                (a['espece'] ?? '').toString().toLowerCase().contains(query);
        final matchFilter = _selectedFilter == 'Tous' ||
            (a['espece'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_selectedFilter.toLowerCase());
        return matchSearch && matchFilter;
      }).toList();
    });
  }

  void _setFilter(String f) {
    setState(() => _selectedFilter = f);
    _applyFilter();
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

  Color _getAvatarColor(String espece) {
    final e = espece.toLowerCase();
    if (e.contains('chien')) return const Color(0xFFFFF3E0);
    if (e.contains('chat')) return const Color(0xFFF3E5F5);
    if (e.contains('lapin')) return const Color(0xFFE8F5E9);
    return const Color(0xFFE3F2FD);
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0),
      body: Column(children: [
        _buildAppBar(),
        _buildSearchBar(),
        _buildFilters(),
        Expanded(child: _buildBody()),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
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
          Text('🐾 Patients',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          Text('Gestion des animaux',
              style: TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_filtered.length} animal${_filtered.length > 1 ? 'x' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
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
            hintText: 'Rechercher un animal, client, espèce...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  // ── FILTRES ───────────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final selected = _selectedFilter == f;
            return GestureDetector(
              onTap: () => _setFilter(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? primary : Colors.white,
                  border: Border.all(
                      color: selected ? primary : const Color(0xFFDDDDDD)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(f,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : Colors.grey[600],
                    )),
              ),
            );
          }).toList(),
        ),
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
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🐾', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Aucun animal trouvé',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Modifiez votre recherche ou ajoutez un patient',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _filtered.length,
        itemBuilder: (context, i) => _buildCard(_filtered[i]),
      ),
    );
  }

  // ── CARD ──────────────────────────────────────────────────────────────────

  Widget _buildCard(dynamic animal) {
    final espece = animal['espece'] ?? '';
    return GestureDetector(
      onTap: () => _showDetail(animal),
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
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _getAvatarColor(espece),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(_getEmoji(espece),
                    style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(animal['nom'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(
                [
                  espece,
                  if ((animal['race'] ?? '').isNotEmpty) animal['race'],
                  if ((animal['sexe'] ?? '').isNotEmpty) animal['sexe'],
                  if ((animal['poids'] ?? 0) > 0) '${animal['poids']} kg',
                ].join(' • '),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(animal['client'] ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ]),
        ]),
      ),
    );
  }

  // ── DETAIL BOTTOM SHEET ───────────────────────────────────────────────────

  void _showDetail(dynamic animal) {
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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _getAvatarColor(animal['espece'] ?? ''),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
                child: Text(_getEmoji(animal['espece'] ?? ''),
                    style: const TextStyle(fontSize: 32))),
          ),
          const SizedBox(height: 12),
          Text(animal['nom'] ?? '',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          Text(animal['client'] ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),
          _infoRow('Espèce',
              (animal['espece'] ?? '').isNotEmpty ? animal['espece'] : '—'),
          _infoRow(
              'Race', (animal['race'] ?? '').isNotEmpty ? animal['race'] : '—'),
          _infoRow(
              'Sexe', (animal['sexe'] ?? '').isNotEmpty ? animal['sexe'] : '—'),
          _infoRow('Poids',
              (animal['poids'] ?? 0) > 0 ? '${animal['poids']} kg' : '—'),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditDialog(animal);
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
                  _confirmDelete(animal);
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

  void _confirmDelete(dynamic animal) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer cet animal ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: Text(
            'Voulez-vous supprimer ${animal['nom']} ?\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _supprimerAnimal(animal['id']);
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
    final especeCtrl = TextEditingController();
    final raceCtrl = TextEditingController();
    final poidsCtrl = TextEditingController();
    String? selectedSexe;
    dynamic selectedClient;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ajouter un animal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Sélection client
              _dropdownClients(
                selectedClient: selectedClient,
                onChanged: (v) => setDialog(() => selectedClient = v),
              ),
              const SizedBox(height: 12),
              _dialogField(nomCtrl, 'Nom *', Icons.pets),
              const SizedBox(height: 12),
              _dialogField(especeCtrl, 'Espèce *', Icons.category_outlined),
              const SizedBox(height: 12),
              _dialogField(raceCtrl, 'Race', Icons.info_outline),
              const SizedBox(height: 12),
              // Sexe dropdown
              _dropdownSexe(
                selectedSexe: selectedSexe,
                onChanged: (v) => setDialog(() => selectedSexe = v),
              ),
              const SizedBox(height: 12),
              _dialogField(
                  poidsCtrl, 'Poids (kg)', Icons.monitor_weight_outlined,
                  type: TextInputType.number),
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
                if (nomCtrl.text.trim().isEmpty ||
                    especeCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Nom et Espèce sont obligatoires'),
                        backgroundColor: Colors.orange),
                  );
                  return;
                }
                if (selectedClient == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Veuillez sélectionner un client'),
                        backgroundColor: Colors.orange),
                  );
                  return;
                }
                Navigator.pop(context);
                _ajouterAnimal({
                  'client_id': selectedClient['id'],
                  'nom': nomCtrl.text.trim(),
                  'espece': especeCtrl.text.trim(),
                  'race': raceCtrl.text.trim(),
                  'sexe': selectedSexe ?? '',
                  'poids': double.tryParse(poidsCtrl.text) ?? 0,
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
      ),
    );
  }

  // ── DIALOG MODIFICATION ───────────────────────────────────────────────────

  void _showEditDialog(dynamic animal) {
    final nomCtrl = TextEditingController(text: animal['nom'] ?? '');
    final especeCtrl = TextEditingController(text: animal['espece'] ?? '');
    final raceCtrl = TextEditingController(text: animal['race'] ?? '');
    final poidsCtrl = TextEditingController(
        text: (animal['poids'] ?? 0) > 0 ? '${animal['poids']}' : '');
    String? selectedSexe =
        (animal['sexe'] ?? '').isNotEmpty ? animal['sexe'] : null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Modifier l\'animal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dialogField(nomCtrl, 'Nom *', Icons.pets),
              const SizedBox(height: 12),
              _dialogField(especeCtrl, 'Espèce *', Icons.category_outlined),
              const SizedBox(height: 12),
              _dialogField(raceCtrl, 'Race', Icons.info_outline),
              const SizedBox(height: 12),
              _dropdownSexe(
                selectedSexe: selectedSexe,
                onChanged: (v) => setDialog(() => selectedSexe = v),
              ),
              const SizedBox(height: 12),
              _dialogField(
                  poidsCtrl, 'Poids (kg)', Icons.monitor_weight_outlined,
                  type: TextInputType.number),
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
                Navigator.pop(context);
                _modifierAnimal(animal['id'], {
                  'nom': nomCtrl.text.trim(),
                  'espece': especeCtrl.text.trim(),
                  'race': raceCtrl.text.trim(),
                  'sexe': selectedSexe ?? '',
                  'poids': double.tryParse(poidsCtrl.text) ?? 0,
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
      ),
    );
  }

  // ── WIDGETS HELPER ────────────────────────────────────────────────────────

  Widget _dropdownClients({
    required dynamic selectedClient,
    required void Function(dynamic) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: selectedClient,
          isExpanded: true,
          hint: const Text('Sélectionner un client *',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: _clients.map<DropdownMenuItem<dynamic>>((c) {
            return DropdownMenuItem<dynamic>(
              value: c,
              child: Text(c['nom'] ?? '', style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dropdownSexe({
    required String? selectedSexe,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSexe,
          isExpanded: true,
          hint: const Text('Sexe',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: const [
            DropdownMenuItem(value: 'Mâle', child: Text('Mâle')),
            DropdownMenuItem(value: 'Femelle', child: Text('Femelle')),
            DropdownMenuItem(value: 'Inconnu', child: Text('Inconnu')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

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
