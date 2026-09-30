import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class OrdonnanceScreen extends StatefulWidget {
  final int consultationId;
  final dynamic ordonnance;

  const OrdonnanceScreen({
    super.key,
    required this.consultationId,
    required this.ordonnance,
  });

  @override
  State<OrdonnanceScreen> createState() => _OrdonnanceScreenState();
}

class _OrdonnanceScreenState extends State<OrdonnanceScreen> {
  static const primary = Color(0xFF1F6FEB);
  static const primaryDark = Color(0xFF0D47A1);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  bool _loading = true;
  Map _consultationData = {};
  List _lignesOrdonnance = [];
  List _medicamentsDisponibles = [];
  bool _isTerminee = false;

  String? _rdvDateAffichage;
  String? _rdvMotifAffichage;

  @override
  void initState() {
    super.initState();
    _fetchOrdonnanceDetails();
  }

  Future<void> _fetchOrdonnanceDetails() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get("consultations/api/${widget.consultationId}/ordonnance/");
      final data = res.data;

      if (mounted) {
        setState(() {
          _consultationData = data['consultation'] ?? data;
          _lignesOrdonnance = data['lignes'] ?? data['ordonnance'] ?? data['items'] ?? [];
          _medicamentsDisponibles = data['medicaments_disponibles'] ?? [];

          final statut = (_consultationData['statut'] ?? '').toString().toLowerCase();
          _isTerminee = statut == 'terminee' || statut == 'terminée' || statut == 'termine';

          final rdvListe = data['rendez_vous'] as List?;
          if (rdvListe != null && rdvListe.isNotEmpty) {
            final premier = rdvListe.first as Map;
            _rdvDateAffichage = premier['date_rdv_affichage']?.toString();
            _rdvMotifAffichage = premier['motif']?.toString();
          } else {
            final rdvDate = _consultationData['rdv_date'] != null
                ? DateTime.tryParse(_consultationData['rdv_date'].toString())
                : null;
            String? heureAffichage;
            if (_consultationData['rdv_heure'] != null) {
              final parts = _consultationData['rdv_heure'].toString().split(':');
              if (parts.length >= 2) {
                heureAffichage = "${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}";
              }
            }
            if (rdvDate != null) {
              _rdvDateAffichage = "${rdvDate.day.toString().padLeft(2, '0')}/${rdvDate.month.toString().padLeft(2, '0')}/${rdvDate.year}"
                  "${heureAffichage != null ? ' à $heureAffichage' : ''}";
            } else {
              _rdvDateAffichage = null;
            }
            _rdvMotifAffichage = _consultationData['rdv_motif']?.toString();
          }

          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _consultationData = widget.ordonnance is Map ? widget.ordonnance : {};
          _loading = false;
        });
      }
    }
  }

  Future<void> _terminerConsultation() async {
    if (_lignesOrdonnance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Impossible de clôturer : ajoutez au moins un médicament à l'ordonnance."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      List payloadMeds = _lignesOrdonnance.map((l) {
        final medId = l['medicament_id'] ?? l['medicament'] ?? l['id'];
        return {
          'medicament_id': medId,
          'posologie': l['posologie'] ?? '',
          'quantite': int.tryParse((l['quantite'] ?? 1).toString()) ?? 1,
        };
      }).toList();

      final payload = {
        'medicaments': payloadMeds,
      };

      await _dio.post(
        "consultations/api/${widget.consultationId}/ordonnance/",
        data: payload,
      );

      final response = await _dio.post("consultations/api/${widget.consultationId}/terminer/");

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _isTerminee = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Consultation clôturée avec succès !"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      String errorMessage = "Erreur lors de la clôture";
      if (e.response?.data != null) {
        if (e.response?.data is Map) {
          final errMap = e.response?.data as Map;
          errorMessage = errMap['error']?.toString() ??
              errMap['message']?.toString() ??
              errMap.values.first.toString();
        } else {
          errorMessage = e.response?.data?.toString() ?? "Erreur serveur inconnue";
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : $errorMessage"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur inattendue : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _ouvrirModalAjoutLigne() async {
    if (_isTerminee) return;

    try {
      final resPharmacie = await _dio.get("pharmacie/api/medicaments");
      final dataPharmacie = resPharmacie.data;
      List rawMeds = [];

      if (dataPharmacie is List) {
        rawMeds = dataPharmacie;
      } else if (dataPharmacie is Map) {
        rawMeds = dataPharmacie['results'] ?? dataPharmacie['medicaments'] ?? dataPharmacie['data'] ?? [];
      }

      setState(() {
        _medicamentsDisponibles = rawMeds.map((m) {
          return {
            'id': m['id'] ?? m['medicament_id'],
            'nom': m['nom'] ?? m['libelle'] ?? m['catalogue']?['nom'] ?? 'Médicament #${m['id']}',
            'stock': m['stock'] ?? m['quantite_stock'] ?? 0,
            'prix': double.tryParse((m['prix'] ?? m['prix_vente'] ?? 0).toString()) ?? 0.0,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("Erreur chargement pharmacie : $e");
    }

    int? selectedMedId;
    final posologieCtrl = TextEditingController();
    final quantiteCtrl = TextEditingController(text: "1");

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                        const Text("💊 Ajouter un médicament", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryDark)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField(
                      value: selectedMedId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Sélectionner un médicament",
                        border: OutlineInputBorder(),
                      ),
                      items: _medicamentsDisponibles.map((m) {
                        final int id = m['id'] ?? 0;
                        final String nom = m['nom'] ?? 'Médicament #$id';
                        final double prix = m['prix'] ?? 0.0;
                        final int stock = m['stock'] ?? 0;
                        return DropdownMenuItem(
                          value: id,
                          child: Text("$nom ($stock en stock — ${prix}F)", overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() => selectedMedId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: posologieCtrl,
                      decoration: const InputDecoration(
                        labelText: "Posologie (ex: 1 fois par jour)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantiteCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Quantité",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          if (selectedMedId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Veuillez sélectionner un médicament")),
                            );
                            return;
                          }

                          final medObj = _medicamentsDisponibles.firstWhere(
                                (m) => m['id'] == selectedMedId,
                            orElse: () => {},
                          );

                          final qte = int.tryParse(quantiteCtrl.text) ?? 1;
                          final prixUnit = medObj.isNotEmpty ? double.tryParse((medObj['prix'] ?? 0).toString()) ?? 0.0 : 0.0;
                          final nomMed = medObj.isNotEmpty ? (medObj['nom'] ?? 'Médicament') : 'Médicament';

                          setState(() {
                            _lignesOrdonnance.add({
                              'medicament': selectedMedId,
                              'medicament_id': selectedMedId,
                              'medicament_nom': nomMed,
                              'posologie': posologieCtrl.text.trim(),
                              'quantite': qte,
                              'prix_unitaire': prixUnit,
                              'total': qte * prixUnit,
                            });
                          });

                          Navigator.pop(ctx);
                        },
                        child: const Text("Ajouter à la liste", style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final clientNom = _consultationData['client_nom'] ?? _consultationData['client'] ?? 'Non renseigné';
    final clientTel = _consultationData['client_tel'] ?? _consultationData['telephone'] ?? 'Non renseigné';
    final animalNom = _consultationData['animal_nom'] ?? _consultationData['animal'] ?? 'Non renseigné';
    final motif = _consultationData['motif'] ?? 'Non renseigné';
    final veterinaire = _consultationData['veterinaire'] ?? 'Non renseigné';

    final String dateConsultation = _consultationData['date'] ??
        _consultationData['date_creation'] ??
        _consultationData['created_at'] ??
        'Non renseignée';

    double totalEstime = 0.0;
    for (var l in _lignesOrdonnance) {
      final qte = l['quantite'] ?? 1;
      final prix = l['prix_unitaire'] ?? l['prix'] ?? 0.0;
      totalEstime += (qte * prix);
    }

    final rdvResume = _rdvDateAffichage == null
        ? "Aucun"
        : (_rdvMotifAffichage != null && _rdvMotifAffichage!.isNotEmpty
        ? "$_rdvDateAffichage — $_rdvMotifAffichage"
        : _rdvDateAffichage!);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F0),
      appBar: AppBar(
        title: const Text("Détails Consultation & Ordonnance", style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: primaryDark,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Client : $clientNom ($clientTel)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("Patient / Animal : $animalNom", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text("Motif : $motif", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text("Docteur : $veterinaire", style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: primary),
                      const SizedBox(width: 6),
                      Text(
                        "Date et heure : $dateConsultation",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Médicaments prescrits (${_lignesOrdonnance.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDark)),
                if (!_isTerminee)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Ajouter", style: TextStyle(fontSize: 12)),
                    onPressed: _ouvrirModalAjoutLigne,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _lignesOrdonnance.isEmpty
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: const Text("Aucun médicament ajouté.", style: TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lignesOrdonnance.length,
              itemBuilder: (context, index) {
                final ligne = _lignesOrdonnance[index];
                final nomMed = ligne['medicament_nom'] ?? ligne['nom'] ?? 'Médicament';
                final poso = ligne['posologie'] ?? '';
                final qte = ligne['quantite'] ?? 1;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                    children: [
                      const Icon(Icons.medication, color: primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nomMed, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (poso.isNotEmpty) Text("Posologie : $poso", style: const TextStyle(fontSize: 12)),
                            Text("Quantité : $qte", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      if (!_isTerminee)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => setState(() => _lignesOrdonnance.removeAt(index)),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("📊 Résumé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDark)),
                  const Divider(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Rendez-vous prévu :", style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Flexible(
                        child: Text(
                          rdvResume,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total estimé médicaments :", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text("${totalEstime.toStringAsFixed(0)} FCFA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!_isTerminee)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _terminerConsultation,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Clôturer la consultation & Générer la vente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Text("✅ Cette consultation est déjà clôturée.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}