import 'dart:async';

import 'package:parcelles_veto_flutter/core/api/api_client.dart';
import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class RendezVousScreen extends StatefulWidget {
  const RendezVousScreen({super.key});

  @override
  State<RendezVousScreen> createState() => _RendezVousScreenState();
}

class _RendezVousScreenState extends State<RendezVousScreen> {
  // Couleurs adaptées au thème bleu et blanc corporate
  static const primary = Color(0xFF1976D2);
  static const primaryDark = Color(0xFF0D47A1);

  final Dio _dio = ApiClient.authentifie(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  List<dynamic> _allRvList = [];
  List<dynamic> _filteredRvList = []; // Initialisation propre corrigée
  bool _loading = true;
  String? _error;

  // 🔍 Filtres et recherche intelligente
  String _selectedFilter = 'Tous';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRendezVous();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRendezVous() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _dio.get("consultations/api/rdv/");
      final data = res.data;

      List<dynamic> loaded = [];
      if (data is List) {
        loaded = data;
      } else if (data is Map<String, dynamic>) {
        loaded = data['results'] as List<dynamic>? ??
            data['rendezvous'] as List<dynamic>? ??
            [];
      }

      // 📅 Tri chronologique par date décroissante
      loaded.sort((a, b) {
        final dateA = (a['date_rdv'] ?? a['date_heure'] ?? '').toString();
        final dateB = (b['date_rdv'] ?? b['date_heure'] ?? '').toString();
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _allRvList = loaded;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Impossible de charger les rendez-vous: $e";
          _loading = false;
        });
      }
    }
  }

  // 🔎 Logique de filtrage et recherche intelligente multi-champs
  void _applyFilters() {
    setState(() {
      _filteredRvList = _allRvList.where((r) {
        final statut = (r['statut'] ?? 'EN_ATTENTE').toString().toUpperCase();

        // 1. Filtrage par onglet de statut
        bool matchesStatus = true;
        if (_selectedFilter == 'Planifiés') {
          matchesStatus = statut == 'PLANIFIE' || statut == 'EN_ATTENTE';
        } else if (_selectedFilter == 'Confirmés') {
          matchesStatus = statut == 'CONFIRME' || statut == 'CONFIRMÉ';
        } else if (_selectedFilter == 'Terminés') {
          matchesStatus = statut == 'TERMINE' || statut == 'TERMINÉ';
        } else if (_selectedFilter == 'Annulés') {
          matchesStatus = statut == 'ANNULE' || statut == 'ANNULÉ';
        }

        if (!matchesStatus) return false;

        // 2. Recherche intelligente
        if (_searchQuery.isEmpty) return true;

        final q = _searchQuery.toLowerCase();
        final client = (r['client_nom'] ?? r['client'] ?? '').toString().toLowerCase();
        final animal = (r['animal_nom'] ?? r['animal'] ?? '').toString().toLowerCase();
        final motif = (r['motif'] ?? '').toString().toLowerCase();
        final tel = (r['telephone'] ?? '').toString().toLowerCase();
        final adresse = (r['adresse'] ?? '').toString().toLowerCase();
        final espece = (r['espece'] ?? '').toString().toLowerCase();

        return client.contains(q) ||
            animal.contains(q) ||
            motif.contains(q) ||
            tel.contains(q) ||
            adresse.contains(q) ||
            espece.contains(q);
      }).toList();
    });
  }

  // 🔒 Vérifie si la date du RDV est dépassée
  bool _isRendezVousPassed(String dateRaw) {
    if (dateRaw.isEmpty) return false;
    try {
      final String cleanedDate = dateRaw.contains(' à ') ? dateRaw.replaceAll(' à ', 'T') : dateRaw;
      final DateTime rdvDate = DateTime.parse(cleanedDate);
      return DateTime.now().isAfter(rdvDate);
    } catch (e) {
      return false;
    }
  }

  Future<void> _changeStatut(int id, String nouveauStatut, bool isManuel) async {
    try {
      await _dio.post("consultations/api/rdv/$id/statut/", data: {
        'statut': nouveauStatut,
        'is_manuel': isManuel, // 👈 Transmission indispensable pour cibler la bonne table
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour : $nouveauStatut'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadRendezVous();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de mise à jour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddRendezVousModal() {
    final clientCtrl = TextEditingController();
    final animalCtrl = TextEditingController();
    final especeCtrl = TextEditingController(text: 'Chien');
    final telCtrl = TextEditingController();
    final adresseCtrl = TextEditingController();
    final motifCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    const String lieu = 'cabinet';

    // Client choisi dans la base (null = nouveau client saisi à la main)
    Map<String, dynamic>? clientChoisi;
    // Animal choisi parmi ceux du client : null = aucun, '' = autre animal
    String? animalChoisi;
    String race = '';

    void remplirAnimal(Map<String, dynamic>? a) {
      animalChoisi = a == null ? '' : (a['nom'] ?? '').toString();
      animalCtrl.text = a == null ? '' : (a['nom'] ?? '').toString();
      especeCtrl.text = a == null ? '' : (a['espece'] ?? '').toString();
      race = a == null ? '' : (a['race'] ?? '').toString();
    }

    void oublierClient() {
      clientChoisi = null;
      animalChoisi = null;
      race = '';
      clientCtrl.clear();
      telCtrl.clear();
      adresseCtrl.clear();
      animalCtrl.clear();
      especeCtrl.text = 'Chien';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List<Map<String, dynamic>> animauxClient = clientChoisi == null
                ? []
                : ((clientChoisi!['animaux'] as List<dynamic>?) ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nouveau Rendez-vous Manuel',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryDark),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 👤 Client déjà enregistré dans la base
                    if (clientChoisi == null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.person_search, size: 20),
                          label: const Text('Choisir un client déjà enregistré'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                            side: const BorderSide(color: primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            final choix = await showModalBottomSheet<Map<String, dynamic>>(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (_) => _ClientPickerSheet(dio: _dio),
                            );
                            if (choix == null) return;
                            setModalState(() {
                              clientChoisi = choix;
                              clientCtrl.text = (choix['nom'] ?? '').toString();
                              telCtrl.text = (choix['telephone'] ?? '').toString();
                              adresseCtrl.text = (choix['adresse'] ?? '').toString();
                              final animaux = (choix['animaux'] as List<dynamic>?) ?? [];
                              if (animaux.length == 1) {
                                remplirAnimal(Map<String, dynamic>.from(animaux.first as Map));
                              } else {
                                animalChoisi = null;
                                animalCtrl.clear();
                                especeCtrl.clear();
                                race = '';
                              }
                            });
                          },
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC6DAFC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Client sélectionné',
                                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                                  Text(
                                    '${clientChoisi!['nom'] ?? ''} · ${clientChoisi!['telephone'] ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDark),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => setModalState(oublierClient),
                              child: const Text('Changer'),
                            ),
                          ],
                        ),
                      ),

                    // 🐾 Animaux du client sélectionné
                    if (animauxClient.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Animal concerné :',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ...animauxClient.map((a) {
                            final nom = (a['nom'] ?? '').toString();
                            return ChoiceChip(
                              label: Text('$nom (${a['espece'] ?? ''})'),
                              selected: animalChoisi == nom,
                              selectedColor: primary,
                              labelStyle: TextStyle(
                                color: animalChoisi == nom ? Colors.white : Colors.black87,
                              ),
                              onSelected: (_) => setModalState(() => remplirAnimal(a)),
                            );
                          }),
                          ChoiceChip(
                            label: const Text('+ Autre animal'),
                            selected: animalChoisi == '',
                            selectedColor: primary,
                            labelStyle: TextStyle(
                              color: animalChoisi == '' ? Colors.white : Colors.black87,
                            ),
                            onSelected: (_) => setModalState(() => remplirAnimal(null)),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextField(
                      controller: clientCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom du Client / Propriétaire',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: telCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Téléphone',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: adresseCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Adresse',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: animalCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nom de l'Animal / Patient",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: especeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Espèce (ex: Chien, Chat...)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: motifCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Motif du rendez-vous',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text("${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) {
                                setModalState(() => selectedDate = d);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(selectedTime.format(context)),
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (t != null) {
                                setModalState(() => selectedTime = t);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          if (motifCtrl.text.isEmpty || clientCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veuillez remplir les champs obligatoires')),
                            );
                            return;
                          }

                          final dt = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );

                          try {
                            await _dio.post("consultations/api/rdv/manuel/ajouter/", data: {
                              'nom_client': clientCtrl.text,
                              'telephone': telCtrl.text,
                              'adresse': adresseCtrl.text,
                              'nom_animal': animalCtrl.text,
                              'espece': especeCtrl.text,
                              'race': race,
                              'motif': motifCtrl.text,
                              'date_rdv': dt.toIso8601String(),
                              'lieu': lieu,
                              'statut': 'EN_ATTENTE',
                            });

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (!mounted) return;
                            _loadRendezVous();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Rendez-vous programmé avec succès !')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Erreur d\'ajout : $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                        child: const Text('Enregistrer le RDV', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatutColor(String statut) {
    switch (statut.toUpperCase()) {
      case 'CONFIRME':
      case 'CONFIRMÉ':
        return Colors.blue;
      case 'TERMINE':
      case 'TERMINÉ':
        return Colors.green;
      case 'ANNULE':
      case 'ANNULÉ':
        return Colors.red;
      default:
        return Colors.orange; // EN_ATTENTE / PLANIFIE
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Rendez-vous', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRendezVous,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRendezVousModal,
        backgroundColor: primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau RDV', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // 🔍 Barre de recherche intelligente
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _searchQuery = v.trim();
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: "Rechercher par client, animal, motif, tél...",
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search_rounded, color: primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _searchQuery = '';
                    _applyFilters();
                  },
                )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF0F4F8),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // 🏷️ Chips de filtres par statut
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Tous', 'Planifiés', 'Confirmés', 'Terminés', 'Annulés'].map((f) {
                  final isSelected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = f;
                          _applyFilters();
                        });
                      },
                      selectedColor: primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: const Color(0xFFF0F4F8),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 📋 Liste des rendez-vous
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: primary))
                : _error != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: _loadRendezVous, child: const Text('Réessayer')),
                  ],
                ),
              ),
            )
                : _filteredRvList.isEmpty
                ? const Center(child: Text('Aucun rendez-vous trouvé.'))
                : RefreshIndicator(
              onRefresh: _loadRendezVous,
              color: primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredRvList.length,
                itemBuilder: (context, i) => _buildRendezVousCard(_filteredRvList[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRendezVousCard(dynamic rv) {
    final id = rv['id'] ?? 0;
    final client = (rv['client_nom'] ?? rv['client'] ?? 'Client non spécifié').toString();
    final animal = (rv['animal_nom'] ?? rv['animal'] ?? 'Animal non spécifié').toString();
    final motif = (rv['motif'] ?? 'Aucun motif').toString();
    final dateRaw = (rv['date_rdv'] ?? rv['date_heure'] ?? '').toString();
    final String dateFormatted = dateRaw.isNotEmpty ? dateRaw.replaceAll('T', ' à ') : 'Date non fixée';
    final statut = (rv['statut'] ?? 'EN_ATTENTE').toString().toUpperCase();
    final bool isManuel = rv['is_manuel'] == true;
    final String telephone = (rv['telephone'] ?? rv['tel'] ?? rv['phone'] ?? '').toString();
    final String adresse = (rv['adresse'] ?? rv['client_adresse'] ?? '').toString();
    final String espece = rv['espece'] ?? '';

    final statusColor = _getStatutColor(statut);
    final bool isPassed = _isRendezVousPassed(dateRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isManuel ? 'RDV Manuel #$id' : 'RDV #$id',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statut,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Client : $client', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          if (telephone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text('Tél : $telephone', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
          if (adresse.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Adresse : $adresse', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.pets, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Patient/Animal : $animal ${espece.isNotEmpty ? '($espece)' : ''}', style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.event, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text('Date/Heure : $dateFormatted', style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Motif : $motif', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54)),
          const SizedBox(height: 12),

          // 🔒 Verrouillage des actions si la date est passée
          if (isPassed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Text(
                    'Rendez-vous passé (Verrouillé)',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
          // Action Buttons: Confirmer, Terminer, Annuler
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (statut != 'CONFIRME' && statut != 'CONFIRMÉ' && statut != 'TERMINE')
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Confirmer', style: TextStyle(fontSize: 11)),
                        onPressed: () => _changeStatut(id, 'CONFIRME', isManuel),
                      ),
                    ),
                  if (statut != 'TERMINE' && statut != 'TERMINÉ')
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.task_alt, size: 16),
                        label: const Text('Terminer', style: TextStyle(fontSize: 11)),
                        onPressed: () => _changeStatut(id, 'TERMINE', isManuel),
                      ),
                    ),
                  if (statut != 'ANNULE' && statut != 'ANNULÉ')
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Annuler', style: TextStyle(fontSize: 11)),
                      onPressed: () => _changeStatut(id, 'ANNULE', isManuel),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Fenêtre de recherche d'un client déjà enregistré (avec ses animaux).
/// Renvoie le client choisi, ou null si on ferme sans choisir.
class _ClientPickerSheet extends StatefulWidget {
  final Dio dio;

  const _ClientPickerSheet({required this.dio});

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  static const primary = Color(0xFF1976D2);

  final TextEditingController _ctrl = TextEditingController();
  Timer? _attente;
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _charger('');
  }

  @override
  void dispose() {
    _attente?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _charger(String recherche) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.dio.get(
        'consultations/api/clients/',
        queryParameters: {'search': recherche},
      );
      // Une réponse plus ancienne arrive après la frappe suivante : on l'ignore
      if (!mounted || _ctrl.text.trim() != recherche) return;
      final data = res.data;
      final List<dynamic> liste = data is Map
          ? ((data['results'] as List<dynamic>?) ?? [])
          : (data is List ? data : []);
      setState(() {
        _clients = liste.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les clients.';
        _loading = false;
      });
    }
  }

  void _onRecherche(String valeur) {
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 350), () => _charger(valeur.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Choisir un client',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onRecherche,
              decoration: InputDecoration(
                hintText: 'Nom, téléphone ou nom de l\'animal…',
                prefixIcon: const Icon(Icons.search, color: primary),
                filled: true,
                fillColor: const Color(0xFFF0F4F8),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildListe()),
          ],
        ),
      ),
    );
  }

  Widget _buildListe() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: primary));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_clients.isEmpty) {
      return const Center(
        child: Text(
          'Aucun client trouvé.\nFermez cette fenêtre pour le saisir à la main.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      itemCount: _clients.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = _clients[i];
        final nom = (c['nom'] ?? '').toString();
        final animaux = ((c['animaux'] as List<dynamic>?) ?? [])
            .map((a) => ((a as Map)['nom'] ?? '').toString())
            .where((n) => n.isNotEmpty)
            .join(', ');
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE8F0FE),
            child: Text(
              nom.isNotEmpty ? nom[0].toUpperCase() : '?',
              style: const TextStyle(color: primary, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            [c['telephone'] ?? '', if (animaux.isNotEmpty) '🐾 $animaux']
                .where((s) => s.toString().isNotEmpty)
                .join('\n'),
          ),
          isThreeLine: animaux.isNotEmpty,
          onTap: () => Navigator.pop(context, c),
        );
      },
    );
  }
}
