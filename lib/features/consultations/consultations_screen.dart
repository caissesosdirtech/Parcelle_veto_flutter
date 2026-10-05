import 'package:parcelles_veto_flutter/core/api/api_client.dart';
import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'ordonnance_screen.dart';

class ConsultationsScreen extends StatefulWidget {
  final bool autoOpenModal;

  const ConsultationsScreen({super.key, this.autoOpenModal = false});

  @override
  State<ConsultationsScreen> createState() => _ConsultationsScreenState();
}

class _ConsultationsScreenState extends State<ConsultationsScreen> {
  static const primary = Color(0xFF1976D2);
  static const primaryDark = Color(0xFF0D47A1);

  final Dio _dio = ApiClient.authentifie(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  List<dynamic> _allConsultations = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'Tous';

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConsultations();

    if (widget.autoOpenModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddConsultationModal();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConsultations() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _dio.get("consultations/api/liste/");
      final dynamic data = res.data;
      List<dynamic> loaded = [];
      if (data is Map<String, dynamic>) {
        loaded = data['results'] as List<dynamic>? ?? data['consultations'] as List<dynamic>? ?? [];
      } else if (data is List) {
        loaded = data;
      }

      loaded.sort((a, b) {
        final idA = a['id'] ?? 0;
        final idB = b['id'] ?? 0;
        return idB.compareTo(idA);
      });

      if (mounted) {
        setState(() {
          _allConsultations = loaded;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erreur de chargement : $e";
          _loading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _allConsultations.where((c) {
        final stat = (c['statut'] ?? '').toString().toLowerCase();

        bool matchesStatus = true;
        if (_selectedFilter == 'En cours') {
          matchesStatus = stat == 'en_cours' || stat == 'en cours' || stat == 'attente';
        } else if (_selectedFilter == 'Terminées') {
          matchesStatus = stat == 'termine' || stat == 'terminee' || stat == 'terminée';
        } else if (_selectedFilter == 'Annulées') {
          matchesStatus = stat == 'annule' || stat == 'annulee' || stat == 'annulée';
        }

        if (!matchesStatus) return false;

        if (_searchQuery.isEmpty) return true;

        final query = _searchQuery.toLowerCase();
        final id = (c['id'] ?? '').toString().toLowerCase();
        final clientNom = (c['client_nom'] ?? c['client']?['nom'] ?? '').toString().toLowerCase();
        final animalNom = (c['animal_nom'] ?? c['animal']?['nom'] ?? '').toString().toLowerCase();
        final espece = (c['animal_espece'] ?? c['espece'] ?? '').toString().toLowerCase();
        final motif = (c['motif'] ?? '').toString().toLowerCase();
        final poids = (c['poids'] ?? c['animal_poids'] ?? '').toString().toLowerCase();

        return id.contains(query) ||
            clientNom.contains(query) ||
            animalNom.contains(query) ||
            espece.contains(query) ||
            motif.contains(query) ||
            poids.contains(query);
      }).toList();
    });
  }

  Future<void> _cloturerConsultation(int consultationId) async {
    final bool? confirmer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Avertissement'),
          ],
        ),
        content: const Text(
          'Voulez-vous vraiment terminer cette consultation ?\n\n'
              'Cette action va valider la consultation, générer la vente et déduire les produits du stock.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminer définitivement'),
          ),
        ],
      ),
    );

    if (confirmer == true) {
      try {
        final res = await _dio.post("consultations/api/$consultationId/terminer/");

        if (mounted) {
          final message = res.data is Map && res.data['message'] != null
              ? res.data['message']
              : 'Consultation terminée avec succès.';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
          _loadConsultations();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _supprimerConsultation(int consultationId, bool isTerminee) async {
    final bool? confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('Supprimer ?'),
          ],
        ),
        content: Text(
          isTerminee
              ? 'Cette consultation terminée sera supprimée définitivement, '
                  'avec son ordonnance et la vente liée.\n\n'
                  'Les médicaments seront remis en stock.'
              : 'Cette consultation et son ordonnance seront supprimées définitivement.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;
    try {
      final res = await _dio.post("consultations/api/$consultationId/supprimer/");
      if (!mounted) return;
      final restitue = res.data is Map ? (res.data['stock_restitue'] ?? 0) : 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(restitue is num && restitue > 0
              ? 'Consultation supprimée. $restitue unité(s) remise(s) en stock.'
              : 'Consultation supprimée.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadConsultations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de suppression : $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddConsultationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NouvelleConsultationModal(dio: _dio, onSaved: _loadConsultations),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddConsultationModal,
        backgroundColor: primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouvelle Consultation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildAppBar(),
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryDark, primary]),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Consultations & RDV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Suivi des consultations vétérinaires', style: TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadConsultations,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.refresh, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) {
          _searchQuery = value.trim();
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: "Rechercher par client, animal, motif, poids...",
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: const Icon(Icons.search_rounded, color: primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
            onPressed: () {
              _searchCtrl.clear();
              _searchQuery = '';
              _applyFilters();
            },
          )
              : null,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Tous', 'En cours', 'Terminées', 'Annulées'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isSelected = _selectedFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f),
                selected: isSelected,
                onSelected: (_) {
                  _selectedFilter = f;
                  _applyFilters();
                },
                selectedColor: primary,
                labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                backgroundColor: const Color(0xFFF0F4F8),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: primary));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadConsultations, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) return const Center(child: Text('Aucune consultation trouvée'));

    return RefreshIndicator(
      onRefresh: _loadConsultations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filtered.length,
        itemBuilder: (context, i) {
          final item = _filtered[i] as Map<String, dynamic>;
          final String status = (item['statut'] ?? '').toString().toLowerCase();
          final bool isTerminee = status == 'terminee' || status == 'terminée' || status == 'termine';
          final int consultationId = item['id'] ?? 0;
          final String animalNom = item['animal_nom'] ?? item['animal']?['nom'] ?? '';
          final String clientNom = item['client_nom'] ?? item['client']?['nom'] ?? '';
          final String animalPoids = item['poids']?.toString() ?? item['animal_poids']?.toString() ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isTerminee ? const Color(0xFFE3F2FD) : const Color(0xFFE1F5FE),
                        child: Icon(
                          isTerminee ? Icons.check_circle : Icons.medical_services,
                          color: isTerminee ? primaryDark : primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Consultation #${item['id'] ?? ''}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (animalNom.isNotEmpty || clientNom.isNotEmpty)
                              Text(
                                "🐾 ${animalNom.isNotEmpty ? animalNom : 'Animal'} — 👤 ${clientNom.isNotEmpty ? clientNom : 'Client'}",
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isTerminee ? Colors.blue.withValues(alpha: 0.1) : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isTerminee ? primary : Colors.orange),
                        ),
                        child: Text(
                          isTerminee ? 'Terminée' : 'En cours',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isTerminee ? primaryDark : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Motif : ${item['motif'] ?? 'Non renseigné'}",
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                      if (animalPoids.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF90CAF9)),
                          ),
                          child: Text(
                            "⚖️ $animalPoids kg",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryDark),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Supprimer la consultation',
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
                        onPressed: () => _supprimerConsultation(consultationId, isTerminee),
                      ),
                      const Spacer(),
                      if (!isTerminee)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Clôturer', style: TextStyle(fontSize: 12)),
                          onPressed: () => _cloturerConsultation(consultationId),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Ordonnance', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrdonnanceScreen(
                                consultationId: consultationId,
                                ordonnance: item,
                              ),
                            ),
                          );
                          if (mounted) {
                            _loadConsultations();
                          }
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── MODAL DE CRÉATION : FORMULAIRE MODERNE & STRUCTURÉ ──────────────────────

class _NouvelleConsultationModal extends StatefulWidget {
  final Dio dio;
  final VoidCallback onSaved;

  const _NouvelleConsultationModal({required this.dio, required this.onSaved});

  @override
  State<_NouvelleConsultationModal> createState() => _NouvelleConsultationModalState();
}

class _NouvelleConsultationModalState extends State<_NouvelleConsultationModal> {
  static const primary = Color(0xFF1976D2);
  static const primaryDark = Color(0xFF0D47A1);

  bool isExistingMode = true;
  bool isSubmitting = false;

  List<dynamic> clients = [];
  List<dynamic> clientAnimaux = [];
  bool loadingClients = false;

  String? selectedClientId;
  String? selectedPhone;
  String? selectedAdresse;
  String? selectedAnimalId;

  final newClientNameCtrl = TextEditingController();
  final newClientPhoneCtrl = TextEditingController();
  final newClientAdresseCtrl = TextEditingController();

  final animalNameCtrl = TextEditingController();
  String? animalEspece = 'Chien';
  String? animalRace;
  String animalSexe = 'M';
  final animalPoidsCtrl = TextEditingController();

  final motifCtrl = TextEditingController();
  final obsCtrl = TextEditingController();
  String lieu = 'cabinet';

  DateTime? selectedRdvDate;
  final rdvMotifCtrl = TextEditingController();

  final Map<String, List<String>> races = {
    "Chien": ["Chien local", "Berger allemand", "Berger belge Malinois", "Labrador", "Rottweiler", "Husky", "Caniche", "Autre"],
    "Chat": ["Siamois", "Persan", "Maine Coon", "Bengal", "Autre"],
    "Bovin": ["Gobra", "Maure", "Djiakoré", "N'dama", "Zébu", "Holstein", "Autre"],
    "Caprin": ["Chevre du Sahel", "Chevre naine d'Afrique de l'Ouest", "Chevre rousse de Maradi", "Boer", "Alpine", "Autre"],
    "Ovin": ["Ladoum", "Mouton Peul-Peul", "Touabir", "Mérinos", "Suffolk", "Autre"],
    "Volaille": ["Poulet local", "poulet de chair (Broiler)", "Pondeuse", "Oie", "Dinde", "Canard", "Pintade", "Autre"],
    "Cheval": ["M'bayar", "Cheval du fleuve", "Barbe", "Pur-sang arabe", "Autre"],
    "Poisson": ["Tilapia", "Silure", "Autre"],
    "Autre": ["Autre"]
  };

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  @override
  void dispose() {
    newClientNameCtrl.dispose();
    newClientPhoneCtrl.dispose();
    newClientAdresseCtrl.dispose();
    animalNameCtrl.dispose();
    animalPoidsCtrl.dispose();
    motifCtrl.dispose();
    obsCtrl.dispose();
    rdvMotifCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchClients() async {
    setState(() => loadingClients = true);
    try {
      final res = await widget.dio.get("consultations/api/clients/");
      final dynamic data = res.data;

      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('results')) {
        list = data['results'];
      } else if (data is Map && data.containsKey('clients')) {
        list = data['clients'];
      }

      if (mounted) {
        setState(() {
          clients = list;
          loadingClients = false;
        });
      }
    } catch (_) {
      try {
        final res2 = await widget.dio.get("clients/api/");
        final dynamic data2 = res2.data;
        final List<dynamic> list2 = data2 is List ? data2 : (data2['results'] ?? []);
        if (mounted) {
          setState(() {
            clients = list2;
            loadingClients = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => loadingClients = false);
      }
    }
  }

  Future<void> _submit() async {
    final bool isNewAnimalForClient = isExistingMode && (selectedAnimalId == "__new__" || selectedAnimalId == null);

    if (isExistingMode) {
      if (selectedClientId == null) {
        _showError("Veuillez sélectionner un client.");
        return;
      }
      if (selectedAnimalId == null) {
        _showError("Veuillez sélectionner ou créer un animal.");
        return;
      }
    } else {
      if (newClientNameCtrl.text.trim().isEmpty) {
        _showError("Le nom du nouveau client est requis.");
        return;
      }
    }

    setState(() => isSubmitting = true);

    final Map<String, dynamic> payload = {
      'mode': isExistingMode ? "existant" : "nouveau",
      'motif': motifCtrl.text.trim(),
      'observations': obsCtrl.text.trim(),
      'lieu': lieu,
      'poids': animalPoidsCtrl.text.trim(),
    };

    if (isNewAnimalForClient) {
      payload['client_id'] = selectedClientId;
      payload['animal_id'] = "NEW_ANIMAL";
      payload['animal_nom'] = animalNameCtrl.text.trim().isEmpty ? "Non renseigné" : animalNameCtrl.text.trim();
      payload['animal_espece'] = animalEspece ?? 'Chien';
      payload['animal_race'] = animalRace ?? '';
      payload['animal_sexe'] = animalSexe;
      payload['animal_poids'] = animalPoidsCtrl.text.trim();
    } else if (isExistingMode) {
      payload['client_id'] = selectedClientId;
      payload['animal_id'] = selectedAnimalId;
      payload['animal_poids'] = animalPoidsCtrl.text.trim();
    } else {
      payload['client_nom'] = newClientNameCtrl.text.trim();
      payload['client_tel'] = newClientPhoneCtrl.text.trim();
      payload['client_adresse'] = newClientAdresseCtrl.text.trim();

      payload['animal_id'] = "NEW_ANIMAL";
      payload['animal_nom'] = animalNameCtrl.text.trim().isEmpty ? "Non renseigné" : animalNameCtrl.text.trim();
      payload['animal_espece'] = animalEspece ?? 'Chien';
      payload['animal_race'] = animalRace ?? '';
      payload['animal_sexe'] = animalSexe;
      payload['animal_poids'] = animalPoidsCtrl.text.trim();
    }

    if (selectedRdvDate != null) {
      payload['date_rdv'] = selectedRdvDate!.toIso8601String();
      payload['rdv_motif'] = rdvMotifCtrl.text.trim().isNotEmpty
          ? rdvMotifCtrl.text.trim()
          : "Suivi consultation";
      payload['rdv_type'] = lieu == 'domicile' ? "DOMICILE" : "CABINET";
    }

    try {
      final Response<dynamic> res = await widget.dio.post(
        "consultations/api/ajouter/",
        data: payload,
      );

      if (mounted) {
        final data = res.data;
        Navigator.pop(context);
        widget.onSaved();

        final consultationId = data['consultation_id'] ?? data['id'];
        if (consultationId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrdonnanceScreen(
                consultationId: consultationId,
                ordonnance: data,
              ),
            ),
          );
        }

        // Numéro déjà connu : le serveur a rattaché la consultation au client existant
        final bool clientExistant = data is Map && data['client_existant'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(clientExistant
                ? (data['message'] ?? 'Client déjà enregistré : consultation rattachée à sa fiche.').toString()
                : 'Consultation créée avec succès !'),
            backgroundColor: clientExistant ? const Color(0xFF0A7BD6) : primary,
            duration: Duration(seconds: clientExistant ? 6 : 4),
          ),
        );
      }
    } catch (e) {
      String errorDetails = "$e";
      if (e is DioException && e.response?.data != null) {
        errorDetails = e.response?.data.toString() ?? "$e";
      }
      _showError(errorDetails);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showError(String msg) {
    String cleanMsg = msg;
    if (msg.contains("telephone") && (msg.contains("already exists") || msg.contains("unique constraint"))) {
      cleanMsg = "⚠️ Ce numéro de téléphone est déjà utilisé par un autre client.";
    } else if (msg.contains("unique constraint")) {
      cleanMsg = "⚠️ Un enregistrement avec ces informations existe déjà.";
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Text("Information")]),
        content: SingleChildScrollView(child: Text(cleanMsg)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showNewAnimalForm = (!isExistingMode) || (isExistingMode && selectedAnimalId == "__new__");

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("🩺 Nouvelle consultation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryDark)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),

            // Sélecteur de mode (Client existant / Nouveau client)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isExistingMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isExistingMode ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "👤 Client existant",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isExistingMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isExistingMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isExistingMode ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "➕ Nouveau client",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: !isExistingMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (isExistingMode) ...[
              const Text("CLIENT & ANIMAL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              loadingClients
                  ? const LinearProgressIndicator(color: primary)
                  : DropdownButtonFormField<String>(
                value: selectedClientId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: "Sélectionner un client",
                  prefixIcon: const Icon(Icons.person_outline, color: primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
                items: clients.map((c) {
                  final String id = c['id'].toString();
                  final String label = c['label'] ?? c['nom_complet'] ?? c['nom'] ?? 'Client #$id';
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  final found = clients.firstWhere(
                        (e) => e['id'].toString() == val,
                    orElse: () => null,
                  );

                  setState(() {
                    selectedClientId = val;
                    selectedPhone = found?['telephone'] ?? found?['phone'] ?? '';
                    selectedAdresse = found?['adresse'] ?? '';

                    final embeddedAnimaux = (found?['animaux'] as List?) ?? [];
                    clientAnimaux = embeddedAnimaux
                        .where((a) => a['id'] != 'NEW_ANIMAL' && a['is_new'] != true)
                        .toList();

                    if (clientAnimaux.isNotEmpty) {
                      selectedAnimalId = clientAnimaux.first['id'].toString();
                    } else {
                      selectedAnimalId = "__new__";
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: TextEditingController(text: selectedPhone), readOnly: true, decoration: InputDecoration(labelText: "Téléphone", prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(controller: TextEditingController(text: selectedAdresse), readOnly: true, decoration: InputDecoration(labelText: "Adresse", prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
                ],
              ),
              const SizedBox(height: 12),
              if (selectedClientId != null)
                DropdownButtonFormField<String>(
                  value: clientAnimaux.any((a) => a['id'].toString() == selectedAnimalId) ? selectedAnimalId : "__new__",
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: "Animal concerné",
                    prefixIcon: const Icon(Icons.pets, color: primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  items: [
                    ...clientAnimaux.map((a) {
                      final aid = a['id'].toString();
                      final anom = a['nom'] ?? 'Animal #$aid';
                      final aesp = a['espece'] ?? '';
                      return DropdownMenuItem<String>(
                        value: aid,
                        child: Text("🐾 $anom ($aesp)", overflow: TextOverflow.ellipsis),
                      );
                    }),
                    const DropdownMenuItem<String>(
                      value: "__new__",
                      child: Text("➕ Ajouter un nouvel animal...", style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => selectedAnimalId = val);
                  },
                ),
            ] else ...[
              const Text("NOUVEAU CLIENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: newClientNameCtrl,
                decoration: InputDecoration(
                  labelText: "Nom complet du client *",
                  prefixIcon: const Icon(Icons.person_outline, color: primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: newClientPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Téléphone",
                        prefixIcon: const Icon(Icons.phone_outlined, color: primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: newClientAdresseCtrl,
                      decoration: InputDecoration(
                        labelText: "Adresse",
                        prefixIcon: const Icon(Icons.location_on_outlined, color: primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (showNewAnimalForm) ...[
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 4),
              const Text("INFORMATIONS DE L'ANIMAL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: animalNameCtrl,
                      decoration: InputDecoration(
                        labelText: "Nom de l'animal",
                        prefixIcon: const Icon(Icons.pets, color: primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: animalPoidsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: "Poids (kg)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: animalEspece,
                      decoration: InputDecoration(
                        labelText: "Espèce",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: races.keys.map((esp) => DropdownMenuItem(value: esp, child: Text(esp))).toList(),
                      onChanged: (val) {
                        setState(() {
                          animalEspece = val;
                          animalRace = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: animalSexe,
                      decoration: InputDecoration(
                        labelText: "Sexe",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('Mâle (M)')),
                        DropdownMenuItem(value: 'F', child: Text('Femelle (F)')),
                      ],
                      onChanged: (val) => setState(() => animalSexe = val ?? 'M'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: animalRace,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: "Race",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
                items: (races[animalEspece] ?? ["Autre"]).map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => animalRace = val),
              ),
            ],

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 4),
            const Text("DÉTAILS DE LA CONSULTATION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            TextFormField(
              controller: motifCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Motif de consultation *",
                prefixIcon: const Icon(Icons.medical_services_outlined, color: primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: obsCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Observations cliniques",
                prefixIcon: const Icon(Icons.note_alt_outlined, color: primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: lieu,
              decoration: InputDecoration(
                labelText: "Lieu de consultation",
                prefixIcon: const Icon(Icons.place_outlined, color: primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
              items: const [
                DropdownMenuItem(value: 'cabinet', child: Text('Au Cabinet')),
                DropdownMenuItem(value: 'domicile', child: Text('À Domicile')),
              ],
              onChanged: (val) => setState(() => lieu = val ?? 'cabinet'),
            ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 4),
            const Text("PLANIFICATION DE RENDEZ-VOUS (OPTIONNEL)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    icon: const Icon(Icons.calendar_today, size: 16, color: primary),
                    label: Text(
                      selectedRdvDate == null
                          ? "Ajouter une date de RDV"
                          : "${selectedRdvDate!.day}/${selectedRdvDate!.month}/${selectedRdvDate!.year} à ${selectedRdvDate!.hour}:${selectedRdvDate!.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null && context.mounted) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            selectedRdvDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                ),
                if (selectedRdvDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => setState(() => selectedRdvDate = null),
                  ),
              ],
            ),

            if (selectedRdvDate != null) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: rdvMotifCtrl,
                decoration: InputDecoration(
                  labelText: "Motif du rendez-vous",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
            ],

            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Enregistrer et créer l'ordonnance", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}