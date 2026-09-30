import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class VenteDetailBottomSheet extends StatefulWidget {
  final dynamic vente;

  const VenteDetailBottomSheet({super.key, required this.vente});

  @override
  State<VenteDetailBottomSheet> createState() => _VenteDetailBottomSheetState();
}

class _VenteDetailBottomSheetState extends State<VenteDetailBottomSheet> {
  static const primary = Color(0xFF2E7D4F);
  static const primaryDark = Color(0xFF1B4D2E);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  List<dynamic> _lignes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetailsVente();
  }

  double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val.replaceAll('FCFA', '').replaceAll(' ', '').trim()) ?? 0.0;
    }
    return 0.0;
  }

  double _getVenteMontant(dynamic venteMap) {
    if (venteMap is! Map) return 0.0;
    final keys = ['montant_total', 'total', 'montant', 'prix_total', 'montant_paye', 'total_vente'];
    for (final k in keys) {
      if (venteMap.containsKey(k) && venteMap[k] != null) {
        final amt = _parseAmount(venteMap[k]);
        if (amt > 0) return amt;
      }
    }
    return 0.0;
  }

  /// Extrait le nom du client, où qu'il soit dans la structure JSON.
  String _getClientNom(Map venteMap) {
    if (venteMap['client_nom'] != null) return venteMap['client_nom'].toString();
    if (venteMap['client_name'] != null) return venteMap['client_name'].toString();
    if (venteMap['client'] is Map) {
      final c = venteMap['client'];
      return (c['nom'] ?? c['name'] ?? '').toString();
    }
    if (venteMap['client'] is String) return venteMap['client'];
    if (venteMap['ordonnance'] is Map) {
      final o = venteMap['ordonnance'];
      if (o['client_nom'] != null) return o['client_nom'].toString();
      if (o['consultation'] is Map && o['consultation']['client_nom'] != null) {
        return o['consultation']['client_nom'].toString();
      }
    }
    return '';
  }

  String _getClientTel(Map venteMap) {
    if (venteMap['client_tel'] != null) return venteMap['client_tel'].toString();
    if (venteMap['telephone'] != null) return venteMap['telephone'].toString();
    if (venteMap['client'] is Map) {
      final c = venteMap['client'];
      return (c['telephone'] ?? c['tel'] ?? '').toString();
    }
    return '';
  }

  String _getAnimalNom(Map venteMap) {
    if (venteMap['animal_nom'] != null) return venteMap['animal_nom'].toString();
    if (venteMap['animal'] is Map) return (venteMap['animal']['nom'] ?? '').toString();
    if (venteMap['ordonnance'] is Map) {
      final o = venteMap['ordonnance'];
      if (o['consultation'] is Map && o['consultation']['animal_nom'] != null) {
        return o['consultation']['animal_nom'].toString();
      }
    }
    return '';
  }

  bool _venteLieeAOrdonnance(Map venteMap) {
    return venteMap['ordonnance'] != null || venteMap['ordonnance_id'] != null || venteMap['consultation_id'] != null;
  }

  Future<void> _loadDetailsVente() async {
    final venteMap = widget.vente is Map<String, dynamic>
        ? widget.vente
        : Map<String, dynamic>.from(widget.vente);

    final venteId = venteMap['id'];
    if (venteId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final res = await _dio.get("ventes/api/$venteId/");
      if (mounted) {
        setState(() {
          final data = res.data;
          if (data is Map<String, dynamic>) {
            widget.vente.addAll(data);
            _lignes = data['lignes'] as List<dynamic>? ??
                data['items'] as List<dynamic>? ??
                data['produits'] as List<dynamic>? ??
                data['details'] as List<dynamic>? ?? [];
          } else if (data is List) {
            _lignes = data;
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur chargement détail vente : $e");
      if (mounted) {
        setState(() {
          _lignes = venteMap['lignes'] as List<dynamic>? ??
              venteMap['items'] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venteMap = widget.vente is Map<String, dynamic>
        ? widget.vente
        : Map<String, dynamic>.from(widget.vente);

    final id = venteMap['id'] ?? 0;
    final date = (venteMap['date'] ?? venteMap['created_at'] ?? venteMap['date_vente'] ?? '—').toString();
    final clientNom = _getClientNom(venteMap);
    final clientTel = _getClientTel(venteMap);
    final animalNom = _getAnimalNom(venteMap);
    final veterinaire = (venteMap['veterinaire'] ?? venteMap['vendeur'] ?? '').toString();
    final modePaiement = (venteMap['mode_paiement'] ?? venteMap['paiement'] ?? '').toString();
    final estOrdonnance = _venteLieeAOrdonnance(venteMap);
    final isAnonyme = clientNom.trim().isEmpty ||
        clientNom.toLowerCase() == 'anonyme' ||
        clientNom.toLowerCase() == 'none';

    double totalVente = _getVenteMontant(venteMap);
    if (totalVente == 0 && _lignes.isNotEmpty) {
      for (var l in _lignes) {
        final itemMap = l is Map<String, dynamic> ? l : Map<String, dynamic>.from(l);
        final qte = _parseAmount(itemMap['quantite'] ?? itemMap['qty'] ?? 1);
        final pu = _parseAmount(itemMap['prix_unitaire'] ?? itemMap['prix'] ?? 0);
        final st = _parseAmount(itemMap['sous_total'] ?? itemMap['total']);
        totalVente += (st > 0) ? st : (qte * pu);
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // ── En-tête : numéro + total ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Vente #$id', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '${totalVente.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // ── Badge type de vente ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: estOrdonnance ? const Color(0xFFE3F2FD) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              estOrdonnance ? '📋 Issue d\'une ordonnance' : '🧾 Vente directe',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: estOrdonnance ? const Color(0xFF1976D2) : const Color(0xFFE65100),
              ),
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE8E8E5)),
          const SizedBox(height: 14),

          // ── Infos client / animal / date ──
          Flexible(
            flex: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.person_outline, "Client", isAnonyme ? "Vente directe (anonyme)" : (clientNom.isEmpty ? "Non renseigné" : clientNom)),
                  if (!isAnonyme && clientTel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _infoRow(Icons.phone_outlined, "Téléphone", clientTel),
                  ],
                  if (animalNom.isNotEmpty && animalNom != "Non renseigné") ...[
                    const SizedBox(height: 6),
                    _infoRow(Icons.pets_outlined, "Animal", animalNom),
                  ],
                  const SizedBox(height: 6),
                  _infoRow(Icons.access_time, "Date", date),
                  if (veterinaire.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _infoRow(Icons.medical_services_outlined, "Vétérinaire", veterinaire),
                  ],
                  if (modePaiement.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _infoRow(Icons.payments_outlined, "Paiement", modePaiement),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'Produits (${_lignes.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryDark),
          ),
          const SizedBox(height: 8),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator(color: primary)),
            )
          else if (_lignes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Aucun produit détaillé disponible.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _lignes.length,
                separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF0F0EE)),
                itemBuilder: (context, index) => _buildLigneItem(_lignes[index]),
              ),
            ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE8E8E5)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(
                '${totalVente.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primary),
              ),
            ],
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: const Text('Fermer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: primary),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildLigneItem(dynamic ligne) {
    final itemMap = ligne is Map<String, dynamic> ? ligne : Map<String, dynamic>.from(ligne);

    String nomProduit = 'Produit';
    if (itemMap['produit_nom'] != null) {
      nomProduit = itemMap['produit_nom'].toString();
    } else if (itemMap['nom_produit'] != null) {
      nomProduit = itemMap['nom_produit'].toString();
    } else if (itemMap['medicament_nom'] != null) {
      nomProduit = itemMap['medicament_nom'].toString();
    } else if (itemMap['designation'] != null) {
      nomProduit = itemMap['designation'].toString();
    } else if (itemMap['produit'] is Map) {
      nomProduit = itemMap['produit']['nom'] ?? itemMap['produit']['designation'] ?? 'Produit';
    } else if (itemMap['medicament'] is Map) {
      nomProduit = itemMap['medicament']['nom'] ?? 'Produit';
    } else if (itemMap['produit'] != null && itemMap['produit'] is String) {
      nomProduit = itemMap['produit'].toString();
    } else if (itemMap['nom'] != null) {
      nomProduit = itemMap['nom'].toString();
    }

    final quantite = _parseAmount(itemMap['quantite'] ?? itemMap['qty'] ?? 1);
    final prixUnitaire = _parseAmount(itemMap['prix_unitaire'] ?? itemMap['prix'] ?? 0);
    final rawSousTotal = _parseAmount(itemMap['sous_total'] ?? itemMap['montant_total'] ?? itemMap['total']);
    final totalLigne = (rawSousTotal > 0) ? rawSousTotal : (quantite * prixUnitaire);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nomProduit,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                '${quantite.toStringAsFixed(0)} x ${prixUnitaire.toStringAsFixed(0)} FCFA',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${totalLigne.toStringAsFixed(0)} FCFA',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
        ),
      ],
    );
  }
}