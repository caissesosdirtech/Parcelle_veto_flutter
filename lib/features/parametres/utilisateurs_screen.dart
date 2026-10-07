import 'package:flutter/material.dart';

import 'parametres_api.dart';

/// Gestion des comptes de l'équipe (réservée au docteur).
class UtilisateursScreen extends StatefulWidget {
  const UtilisateursScreen({super.key});

  @override
  State<UtilisateursScreen> createState() => _UtilisateursScreenState();
}

class _UtilisateursScreenState extends State<UtilisateursScreen> {
  static const bleu = Color(0xFF0B47C9);
  static const vert = Color(0xFF08C792);
  static const encre = Color(0xFF0F2547);
  static const gris = Color(0xFF6B7A90);
  static const longueurMin = 8;

  List<Map<String, dynamic>> _utilisateurs = [];
  List<Map<String, dynamic>> _roles = [];
  int? _moi;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ParametresApi.utilisateurs();
      if (!mounted) return;
      setState(() {
        _moi = data['moi'] as int?;
        _roles = ((data['roles'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _utilisateurs = ((data['utilisateurs'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ParametresApi.erreur(e);
        _loading = false;
      });
    }
  }

  void _message(String texte, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texte),
      backgroundColor: erreur ? Colors.red.shade700 : const Color(0xFF15803D),
    ));
  }

  Color _couleurRole(String role) {
    switch (role) {
      case 'DOCTEUR':
        return bleu;
      case 'ASSISTANT':
        return const Color(0xFFB45309);
      case 'PHARMACIEN':
        return const Color(0xFF15803D);
      default:
        return gris;
    }
  }

  String? _verifierMdp(String? v) {
    final mdp = v ?? '';
    if (mdp.length < longueurMin) return '$longueurMin caractères minimum';
    if (RegExp(r'^\d+$').hasMatch(mdp)) return 'Pas uniquement des chiffres';
    return null;
  }

  // ── Ajouter / modifier ────────────────────────────────────────────────────
  Future<void> _ouvrirFormulaire([Map<String, dynamic>? u]) async {
    final creation = u == null;
    final cleForm = GlobalKey<FormState>();
    final prenom = TextEditingController(text: u?['first_name'] ?? '');
    final nom = TextEditingController(text: u?['last_name'] ?? '');
    final tel = TextEditingController(text: u?['telephone'] ?? '');
    final identifiant = TextEditingController();
    final mdp = TextEditingController();
    // Un rôle inconnu (ancien « EMPLOYE »…) n'est pas présélectionné :
    // la liste exige que la valeur fasse partie des choix proposés.
    String role = (u?['role'] ?? '').toString();
    if (!_roles.any((r) => r['code'] == role)) role = '';
    final estMoi = u != null && u['id'] == _moi;
    bool envoi = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Form(
            key: cleForm,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    creation ? 'Nouvel utilisateur' : 'Modifier le compte',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: encre),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _champ(prenom, 'Prénom')),
                    const SizedBox(width: 10),
                    Expanded(child: _champ(nom, 'Nom')),
                  ]),
                  const SizedBox(height: 12),
                  _champ(tel, 'Téléphone', clavier: TextInputType.phone),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role.isEmpty ? null : role,
                    decoration: _deco('Rôle'),
                    items: _roles
                        .map((r) => DropdownMenuItem<String>(
                              value: r['code'].toString(),
                              child: Text(r['libelle'].toString()),
                            ))
                        .toList(),
                    onChanged: estMoi ? null : (v) => setSheet(() => role = v ?? ''),
                    validator: (v) => (v == null || v.isEmpty) ? 'Choisissez un rôle' : null,
                  ),
                  if (estMoi)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Vous ne pouvez pas modifier votre propre rôle.',
                          style: TextStyle(fontSize: 12, color: gris)),
                    ),
                  if (creation) ...[
                    const SizedBox(height: 12),
                    _champ(identifiant, 'Identifiant de connexion',
                        validateur: (v) => (v == null || v.trim().isEmpty || v.contains(' '))
                            ? 'Obligatoire, sans espace'
                            : null),
                    const SizedBox(height: 12),
                    _champ(mdp, 'Mot de passe provisoire',
                        cache: true, validateur: _verifierMdp),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bleu,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: envoi
                          ? null
                          : () async {
                              if (!cleForm.currentState!.validate()) return;
                              if (prenom.text.trim().isEmpty && nom.text.trim().isEmpty) {
                                _message('Indiquez au moins le prénom ou le nom.', erreur: true);
                                return;
                              }
                              setSheet(() => envoi = true);
                              final donnees = <String, dynamic>{
                                'first_name': prenom.text.trim(),
                                'last_name': nom.text.trim(),
                                'telephone': tel.text.trim(),
                                'role': role,
                                if (creation) 'username': identifiant.text.trim(),
                                if (creation) 'password': mdp.text,
                              };
                              try {
                                final msg = creation
                                    ? await ParametresApi.creer(donnees)
                                    : await ParametresApi.modifier(u!['id'] as int, donnees);
                                if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                                _message(msg);
                              } catch (e) {
                                setSheet(() => envoi = false);
                                _message(ParametresApi.erreur(e), erreur: true);
                              }
                            },
                      child: envoi
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(creation ? 'Créer le compte' : 'Enregistrer',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok == true) _charger();
  }

  // ── Mot de passe ──────────────────────────────────────────────────────────
  Future<void> _reinitialiser(Map<String, dynamic> u) async {
    final cleForm = GlobalKey<FormState>();
    final mdp = TextEditingController();
    final valide = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Nouveau mot de passe'),
        content: Form(
          key: cleForm,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pour ${u['nom_complet']}. Communiquez-le-lui : il pourra le changer dans « Mon compte ».',
                  style: const TextStyle(fontSize: 13, color: gris)),
              const SizedBox(height: 14),
              _champ(mdp, 'Nouveau mot de passe', cache: true, validateur: _verifierMdp),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (cleForm.currentState!.validate()) Navigator.pop(dialogContext, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (valide != true) return;
    try {
      _message(await ParametresApi.reinitialiserMotDePasse(u['id'] as int, mdp.text));
    } catch (e) {
      _message(ParametresApi.erreur(e), erreur: true);
    }
  }

  // ── Activer / désactiver ──────────────────────────────────────────────────
  Future<void> _basculer(Map<String, dynamic> u) async {
    final actif = u['is_active'] == true;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(actif ? 'Désactiver ce compte ?' : 'Réactiver ce compte ?'),
        content: Text(actif
            ? "${u['nom_complet']} ne pourra plus se connecter, ni sur le site ni dans l'app. Son historique est conservé."
            : "${u['nom_complet']} pourra de nouveau se connecter."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actif ? Colors.red.shade600 : const Color(0xFF15803D),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(actif ? 'Désactiver' : 'Réactiver'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      _message(await ParametresApi.basculerActif(u['id'] as int));
      _charger();
    } catch (e) {
      _message(ParametresApi.erreur(e), erreur: true);
    }
  }

  // ── Construction ──────────────────────────────────────────────────────────
  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF2F6FB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Widget _champ(TextEditingController c, String label,
      {bool cache = false,
      TextInputType? clavier,
      String? Function(String?)? validateur}) {
    return TextFormField(
      controller: c,
      obscureText: cache,
      keyboardType: clavier,
      validator: validateur,
      decoration: _deco(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Utilisateurs', style: TextStyle(color: Colors.white, fontSize: 18)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [bleu, vert])),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _charger),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: bleu,
        foregroundColor: Colors.white,
        onPressed: _roles.isEmpty ? null : () => _ouvrirFormulaire(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Ajouter'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: bleu))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _utilisateurs.length,
                    itemBuilder: (context, i) => _carte(_utilisateurs[i]),
                  ),
                ),
    );
  }

  Widget _carte(Map<String, dynamic> u) {
    final actif = u['is_active'] == true;
    final estMoi = u['id'] == _moi;
    final role = (u['role'] ?? '').toString();
    final nom = (u['nom_complet'] ?? u['username'] ?? '').toString();
    final couleur = _couleurRole(role);
    return Opacity(
      opacity: actif ? 1 : 0.55,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: couleur.withValues(alpha: 0.12),
                child: Text(nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                    style: TextStyle(color: couleur, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(estMoi ? '$nom (vous)' : nom,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: encre)),
                    const SizedBox(height: 2),
                    Text('@${u['username']}${(u['telephone'] ?? '').toString().isNotEmpty ? ' · ${u['telephone']}' : ''}',
                        style: const TextStyle(fontSize: 12, color: gris)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: couleur.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text((u['role_libelle'] ?? '').toString(),
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: couleur)),
                      ),
                      if (!actif)
                        const Text('Désactivé',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red)),
                    ]),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (choix) {
                  if (choix == 'modifier') _ouvrirFormulaire(u);
                  if (choix == 'mdp') _reinitialiser(u);
                  if (choix == 'actif') _basculer(u);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                  const PopupMenuItem(value: 'mdp', child: Text('Nouveau mot de passe')),
                  if (!estMoi)
                    PopupMenuItem(
                      value: 'actif',
                      child: Text(actif ? 'Désactiver' : 'Réactiver',
                          style: TextStyle(color: actif ? Colors.red : null)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
