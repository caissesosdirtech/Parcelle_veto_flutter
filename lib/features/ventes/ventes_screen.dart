import 'package:parcelles_veto_flutter/core/api/api_client.dart';
import 'package:parcelles_veto_flutter/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../screens/vente_detail_bottom_sheet.dart';

class VentesScreen extends StatefulWidget {
  const VentesScreen({super.key});

  @override
  State<VentesScreen> createState() => _VentesScreenState();
}

class _VentesScreenState extends State<VentesScreen> {
  // Couleurs adaptées au thème bleu et blanc corporate
  static const primary = Color(0xFF1976D2);
  static const primaryDark = Color(0xFF0D47A1);

  final Dio _dio = ApiClient.authentifie(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  List<dynamic> _ventes = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  double _ventesJour = 0;
  int _totalVentes = 0;
  double _caTotal = 0;
  double _ticketMoyen = 0;

  @override
  void initState() {
    super.initState();
    _loadVentes();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Formatage du nom de client avec gestion du mode anonyme
  String _getClientLabel(dynamic vente) {
    if (vente is! Map) return 'Vente directe';

    String rawClient = '';

    if (vente['client_nom'] != null) {
      rawClient = vente['client_nom'].toString();
    } else if (vente['client_name'] != null) {
      rawClient = vente['client_name'].toString();
    } else if (vente['client'] is Map) {
      final cMap = vente['client'];
      rawClient = (cMap['nom'] ?? cMap['name'] ?? cMap['prenom'] ?? '').toString();
    } else if (vente['client'] != null) {
      rawClient = vente['client'].toString();
    }

    rawClient = rawClient.trim();

    final isAnonymous = rawClient.isEmpty ||
        rawClient == '-' ||
        rawClient.toLowerCase() == 'anonyme' ||
        rawClient.toLowerCase() == 'client passage' ||
        rawClient.toLowerCase() == 'client de passage' ||
        rawClient.toLowerCase() == 'none' ||
        rawClient.toLowerCase() == 'null';

    if (isAnonymous) {
      return 'Vente directe';
    }

    return rawClient;
  }

  double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val.replaceAll('FCFA', '').replaceAll(' ', '').trim()) ?? 0.0;
    }
    return 0.0;
  }

  double _getVenteMontant(dynamic vente) {
    if (vente is! Map) return 0.0;

    final keys = ['montant_total', 'total', 'montant', 'prix_total', 'montant_paye', 'total_vente'];
    for (final k in keys) {
      if (vente.containsKey(k) && vente[k] != null) {
        final amt = _parseAmount(vente[k]);
        if (amt > 0) return amt;
      }
    }
    return 0.0;
  }

  Future<void> _loadVentes() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _dio.get("ventes/api/liste/");
      final dynamic data = res.data;

      List<dynamic> loaded = [];
      if (data is Map<String, dynamic>) {
        loaded = data['results'] as List<dynamic>? ?? data['ventes'] as List<dynamic>? ?? [];
        _ventesJour = _parseAmount(data['ventes_jour'] ?? data['ca_jour'] ?? data['total_aujourdhui']);
        _totalVentes = (data['total_ventes'] ?? data['count'] ?? loaded.length) as int;
        _caTotal = _parseAmount(data['ca_total'] ?? data['total_ca']);
        _ticketMoyen = _parseAmount(data['ticket_moyen']);
      } else if (data is List) {
        loaded = data;
        _totalVentes = loaded.length;
      }

      if (_caTotal == 0 && loaded.isNotEmpty) {
        double sum = 0;
        for (var v in loaded) {
          sum += _getVenteMontant(v);
        }
        _caTotal = sum;
      }

      if (_totalVentes > 0 && _ticketMoyen == 0) {
        _ticketMoyen = _caTotal / _totalVentes;
      }

      if (_ventesJour == 0 && loaded.isNotEmpty) {
        final now = DateTime.now();
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final todayFrStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

        double sumToday = 0;
        for (var v in loaded) {
          final rawDate = (v['date'] ?? v['created_at'] ?? v['date_vente'] ?? '').toString();
          if (rawDate.contains(todayStr) || rawDate.contains(todayFrStr)) {
            sumToday += _getVenteMontant(v);
          }
        }
        _ventesJour = sumToday;
      }

      if (mounted) {
        setState(() {
          _ventes = loaded;
          _filtered = List.from(_ventes);
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

  void _applyFilter() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.from(_ventes);
      } else {
        _filtered = _ventes.where((v) {
          final client = _getClientLabel(v).toLowerCase();
          final id = (v['id'] ?? '').toString();
          return client.contains(query) || id.contains(query);
        }).toList();
      }
    });
  }

  void _showNouvelleVenteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NouvelleVenteDirecteModal(dio: _dio, onSaved: _loadVentes),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Ventes', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVentes,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNouvelleVenteModal,
        backgroundColor: primary,
        icon: const Icon(Icons.point_of_sale, color: Colors.white),
        label: const Text('Vente directe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildKpiGrid(),
          _buildSearchBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filtered.length} ventes',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Text(
                  'Les 50 dernières',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _kpiCard('${_ventesJour.toStringAsFixed(0)} FCFA', 'Ventes du jour', Icons.calendar_today, const Color(0xFFE3F2FD), const Color(0xFF1976D2))),
              const SizedBox(width: 8),
              Expanded(child: _kpiCard('$_totalVentes', 'Total ventes', Icons.receipt_long, const Color(0xFFE1F5FE), const Color(0xFF0288D1))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _kpiCard('${_caTotal.toStringAsFixed(0)} FCFA', 'CA total', Icons.attach_money, const Color(0xFFF3E5F5), const Color(0xFF7B1FA2))),
              const SizedBox(width: 8),
              Expanded(child: _kpiCard('${_ticketMoyen.toStringAsFixed(0)} FCFA', 'Ticket moyen', Icons.insert_chart_outlined, const Color(0xFFE8EAF6), const Color(0xFF3F51B5))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String value, String label, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: iconColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Rechercher par client, ID ou date...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: primary));
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_filtered.isEmpty) return const Center(child: Text('Aucune vente enregistrée.'));

    return RefreshIndicator(
      onRefresh: _loadVentes,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        itemCount: _filtered.length,
        itemBuilder: (context, i) => _buildVenteCard(_filtered[i]),
      ),
    );
  }

  Widget _buildVenteCard(dynamic vente) {
    final id = vente['id'] ?? 0;
    final clientLabel = _getClientLabel(vente);
    final date = vente['date'] ?? vente['created_at'] ?? '';
    final montant = _getVenteMontant(vente);
    final nbProduits = vente['nb_produits'] ?? vente['lignes_count'] ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => VenteDetailBottomSheet(vente: vente),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Vente #$id',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: clientLabel == 'Vente directe'
                                    ? const Color(0xFFEEEEEE)
                                    : const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                clientLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: clientLabel == 'Vente directe'
                                      ? Colors.grey[700]
                                      : const Color(0xFF1976D2),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            date.toString(),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '$nbProduits prod.',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      '${montant.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: primaryDark,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🧾 MODALE : NOUVELLE VENTE DIRECTE (client existant OU anonyme)
// ═══════════════════════════════════════════════════════════════════════════

class _NouvelleVenteDirecteModal extends StatefulWidget {
  final Dio dio;
  final VoidCallback onSaved;

  const _NouvelleVenteDirecteModal({required this.dio, required this.onSaved});

  @override
  State<_NouvelleVenteDirecteModal> createState() => _NouvelleVenteDirecteModalState();
}

class _NouvelleVenteDirecteModalState extends State<_NouvelleVenteDirecteModal> {
  static const primary = Color(0xFF1976D2);
  static const primaryDark = Color(0xFF0D47A1);

  bool isAnonyme = true;
  bool isSubmitting = false;

  List<dynamic> clients = [];
  bool loadingClients = false;
  String? selectedClientId;

  List<dynamic> medicamentsDisponibles = [];
  bool loadingCatalogue = false;
  final List<Map<String, dynamic>> lignesPanier = [];

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchCatalogue();
  }

  Future<void> _fetchClients() async {
    setState(() => loadingClients = true);
    try {
      final res = await widget.dio.get("consultations/api/clients/");
      final data = res.data;
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('results')) {
        list = data['results'];
      }
      if (mounted) setState(() { clients = list; loadingClients = false; });
    } catch (_) {
      try {
        final res2 = await widget.dio.get("clients/api/");
        final data2 = res2.data;
        final list2 = data2 is List ? data2 : (data2['results'] ?? []);
        if (mounted) setState(() { clients = list2; loadingClients = false; });
      } catch (_) {
        if (mounted) setState(() => loadingClients = false);
      }
    }
  }

  Future<void> _fetchCatalogue() async {
    setState(() => loadingCatalogue = true);
    try {
      final res = await widget.dio.get("pharmacie/api/medicaments/");
      final data = res.data;
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('results')) {
        list = data['results'];
      }
      if (mounted) setState(() { medicamentsDisponibles = list; loadingCatalogue = false; });
    } catch (e) {
      debugPrint("❌ Erreur chargement catalogue : $e");
      if (mounted) setState(() => loadingCatalogue = false);
    }
  }

  double get _totalPanier {
    double total = 0;
    for (final l in lignesPanier) {
      total += (l['quantite'] as int) * (l['prix'] as double);
    }
    return total;
  }

  void _ajouterLigneAuPanier() {
    if (medicamentsDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Catalogue indisponible")),
      );
      return;
    }

    int? selectedId;
    final qteCtrl = TextEditingController(text: "1");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 16, right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ajouter un produit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Article / Produit", border: OutlineInputBorder()),
                    items: medicamentsDisponibles.map((m) {
                      final id = m['id'] as int;
                      final nom = m['nom'] ?? 'Produit';
                      final stock = m['stock'] ?? 0;
                      final prix = m['prix'] ?? 0.0;
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text("$nom ($stock en stock — ${prix}F)", overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qteCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Quantité", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                      onPressed: () {
                        if (selectedId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Sélectionnez un produit")),
                          );
                          return;
                        }
                        final med = medicamentsDisponibles.firstWhere((m) => m['id'] == selectedId);
                        final qte = int.tryParse(qteCtrl.text) ?? 1;
                        final prix = double.tryParse((med['prix'] ?? 0).toString()) ?? 0.0;

                        setState(() {
                          lignesPanier.add({
                            'medicament_id': selectedId,
                            'nom': med['nom'] ?? 'Produit',
                            'quantite': qte,
                            'prix': prix,
                          });
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text("Ajouter au panier"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (lignesPanier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ajoutez au moins un produit au panier")),
      );
      return;
    }
    if (!isAnonyme && selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sélectionnez un client ou basculez en vente anonyme")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    final payload = {
      'client_id': isAnonyme ? null : selectedClientId,
      'lignes': lignesPanier.map((l) => {
        'medicament_id': l['medicament_id'],
        'quantite': l['quantite'],
      }).toList(),
    };

    try {
      final res = await widget.dio.post("ventes/api/nouvelle/", data: payload);
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data['message'] ?? 'Vente enregistrée avec succès !'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      String details = "$e";
      if (e is DioException && e.response?.data != null) {
        details = e.response!.data is Map ? (e.response!.data['error']?.toString() ?? e.response!.data.toString()) : e.response!.data.toString();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $details"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20, left: 16, right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("🧾 Nouvelle vente directe", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryDark)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),

            // ── Choix : vente anonyme ou client existant ──
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAnonyme ? primary : Colors.grey[200],
                      foregroundColor: isAnonyme ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setState(() => isAnonyme = true),
                    child: const Text("🙈 Vente anonyme", style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isAnonyme ? primaryDark : Colors.grey[200],
                      foregroundColor: !isAnonyme ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setState(() => isAnonyme = false),
                    child: const Text("👤 Client existant", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (!isAnonyme) ...[
              loadingClients
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                value: selectedClientId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "Client", border: OutlineInputBorder()),
                items: clients.map((c) {
                  final id = c['id'].toString();
                  final label = c['label'] ?? c['nom_complet'] ?? c['nom'] ?? 'Client #$id';
                  return DropdownMenuItem<String>(value: id, child: Text(label, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (val) => setState(() => selectedClientId = val),
              ),
              const SizedBox(height: 14),
            ],

            // ── Panier de produits ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Produits", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                TextButton.icon(
                  onPressed: _ajouterLigneAuPanier,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Ajouter"),
                ),
              ],
            ),
            if (lignesPanier.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text("Aucun produit ajouté", style: TextStyle(color: Colors.grey, fontSize: 13)),
              )
            else
              ...lignesPanier.asMap().entries.map((entry) {
                final i = entry.key;
                final l = entry.value;
                final sousTotal = (l['quantite'] as int) * (l['prix'] as double);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l['nom'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text("${l['quantite']} x ${(l['prix'] as double).toStringAsFixed(0)} FCFA = ${sousTotal.toStringAsFixed(0)} FCFA",
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        onPressed: () => setState(() => lignesPanier.removeAt(i)),
                      ),
                    ],
                  ),
                );
              }),

            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text("${_totalPanier.toStringAsFixed(0)} FCFA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primary)),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Enregistrer la vente", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}