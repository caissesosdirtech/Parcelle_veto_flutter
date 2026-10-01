import 'package:parcelles_veto_flutter/core/api/api_client.dart';
import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/permissions_service.dart';

class FournisseursScreen extends StatefulWidget {
  const FournisseursScreen({super.key});

  @override
  State<FournisseursScreen> createState() => _FournisseursScreenState();
}

class _FournisseursScreenState extends State<FournisseursScreen> {
  // Couleurs adaptées au thème bleu et blanc corporate
  static const primary = Color(0xFF1976D2);
  static const primaryDark = Color(0xFF0D47A1);

  final Dio _dio = ApiClient.authentifie(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  List<dynamic> _fournisseurs = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get("fournisseurs/api/liste/");
      setState(() {
        _fournisseurs = res.data is List ? res.data : [];
        _filtered = List.from(_fournisseurs);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur de connexion : $e";
        _loading = false;
      });
    }
  }

  Future<void> _ajouterFournisseur(Map<String, dynamic> data) async {
    try {
      await _dio.post("fournisseurs/api/ajouter/", data: data);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Fournisseur ajouté ✅'), backgroundColor: primary),
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

  Future<void> _modifierFournisseur(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put("fournisseurs/api/$id/modifier/", data: data);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Fournisseur modifié ✅'), backgroundColor: primary),
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

  Future<void> _supprimerFournisseur(int id) async {
    try {
      await _dio.delete("fournisseurs/api/$id/supprimer/");
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Fournisseur supprimé'),
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

  // ── FILTRE ────────────────────────────────────────────────────────────────

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _fournisseurs.where((f) {
        final nom = (f['nom'] ?? '').toString().toLowerCase();
        final tel = (f['telephone'] ?? '').toString().toLowerCase();
        final email = (f['email'] ?? '').toString().toLowerCase();
        return nom.contains(q) || tel.contains(q) || email.contains(q);
      }).toList();
    });
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  String _initiales(dynamic f) {
    final nom = (f['nom'] ?? '').toString().trim();
    final parts = nom.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return nom.isNotEmpty ? nom[0].toUpperCase() : '?';
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(children: [
        _buildAppBar(),
        _buildSearchBar(),
        Expanded(child: _buildBody()),
      ]),
      floatingActionButton: PermissionsService.canEditFournisseur
          ? FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: primary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child:
        const Icon(Icons.add_business_outlined, color: Colors.white),
      )
          : null,
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
          Text('🚚 Fournisseurs',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          Text('Gestion des partenaires',
              style: TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_filtered.length} fourn.',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
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

  // ── SEARCH ────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Rechercher un fournisseur, téléphone, email...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: Icon(Icons.search, size: 18, color: primary),
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
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🚚', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Aucun fournisseur trouvé',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Modifiez votre recherche ou ajoutez un fournisseur',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _filtered.length,
        itemBuilder: (context, i) => _buildCard(_filtered[i]),
      ),
    );
  }

  // ── CARD ──────────────────────────────────────────────────────────────────

  Widget _buildCard(dynamic f) {
    final nbMeds = f['nb_medicaments'] ?? 0;

    return GestureDetector(
      onTap: () => _showDetail(f),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
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
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(_initiales(f),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f['nom'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(
                [
                  if ((f['telephone'] ?? '').isNotEmpty) f['telephone'],
                  if ((f['email'] ?? '').isNotEmpty) f['email'],
                ].join(' • '),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (nbMeds > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$nbMeds méd.',
                    style: const TextStyle(fontSize: 10, color: primaryDark)),
              ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ]),
        ]),
      ),
    );
  }

  // ── DETAIL ────────────────────────────────────────────────────────────────

  void _showDetail(dynamic f) {
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
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(_initiales(f),
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0))),
            ),
          ),
          const SizedBox(height: 12),
          Text(f['nom'] ?? '',
              style:
              const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          _infoRow('Téléphone',
              (f['telephone'] ?? '').isNotEmpty ? f['telephone'] : '—'),
          _infoRow('Email', (f['email'] ?? '').isNotEmpty ? f['email'] : '—'),
          _infoRow(
              'Adresse', (f['adresse'] ?? '').isNotEmpty ? f['adresse'] : '—'),
          _infoRow('Médicaments fournis', '${f['nb_medicaments'] ?? 0}'),
          const SizedBox(height: 20),
          // ✅ Boutons action
          if (PermissionsService.canEditFournisseur)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditDialog(f);
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
                    _confirmDelete(f);
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
        Flexible(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right),
        ),
      ]),
    );
  }

  // ── CONFIRMER SUPPRESSION ─────────────────────────────────────────────────

  void _confirmDelete(dynamic f) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce fournisseur ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: Text(
            'Voulez-vous vraiment supprimer ${f['nom']} ?\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _supprimerFournisseur(f['id']);
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
    final emailCtrl = TextEditingController();
    final adresseCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ajouter un fournisseur',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nomCtrl, 'Nom *', Icons.store_outlined),
            const SizedBox(height: 12),
            _dialogField(telCtrl, 'Téléphone', Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 12),
            _dialogField(emailCtrl, 'Email', Icons.email_outlined,
                type: TextInputType.emailAddress),
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
                      backgroundColor: Colors.orange),
                );
                return;
              }
              Navigator.pop(context);
              _ajouterFournisseur({
                'nom': nomCtrl.text.trim(),
                'telephone': telCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
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

  void _showEditDialog(dynamic f) {
    final nomCtrl = TextEditingController(text: f['nom'] ?? '');
    final telCtrl = TextEditingController(text: f['telephone'] ?? '');
    final emailCtrl = TextEditingController(text: f['email'] ?? '');
    final adresseCtrl = TextEditingController(text: f['adresse'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifier le fournisseur',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nomCtrl, 'Nom *', Icons.store_outlined),
            const SizedBox(height: 12),
            _dialogField(telCtrl, 'Téléphone', Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 12),
            _dialogField(emailCtrl, 'Email', Icons.email_outlined,
                type: TextInputType.emailAddress),
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
              _modifierFournisseur(f['id'], {
                'nom': nomCtrl.text.trim(),
                'telephone': telCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
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
        fillColor: const Color(0xFFF9FAFC),
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