import 'package:flutter/material.dart';

import 'parametres_api.dart';

/// Mon compte : informations personnelles et changement de mot de passe.
class MonCompteScreen extends StatefulWidget {
  const MonCompteScreen({super.key});

  @override
  State<MonCompteScreen> createState() => _MonCompteScreenState();
}

class _MonCompteScreenState extends State<MonCompteScreen> {
  static const bleu = Color(0xFF0B47C9);
  static const vert = Color(0xFF08C792);
  static const encre = Color(0xFF0F2547);
  static const gris = Color(0xFF6B7A90);

  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _tel = TextEditingController();
  final _ancien = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  final _cleMdp = GlobalKey<FormState>();

  Map<String, dynamic>? _moi;
  bool _loading = true;
  bool _envoiProfil = false;
  bool _envoiMdp = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    for (final c in [_prenom, _nom, _tel, _ancien, _nouveau, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final moi = await ParametresApi.monCompte();
      if (!mounted) return;
      setState(() {
        _moi = moi;
        _prenom.text = (moi['first_name'] ?? '').toString();
        _nom.text = (moi['last_name'] ?? '').toString();
        _tel.text = (moi['telephone'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(ParametresApi.erreur(e), erreur: true);
    }
  }

  void _message(String texte, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texte),
      backgroundColor: erreur ? Colors.red.shade700 : const Color(0xFF15803D),
    ));
  }

  Future<void> _enregistrerProfil() async {
    setState(() => _envoiProfil = true);
    try {
      await ParametresApi.enregistrerMonCompte({
        'first_name': _prenom.text.trim(),
        'last_name': _nom.text.trim(),
        'telephone': _tel.text.trim(),
      });
      _message('Vos informations ont été mises à jour.');
    } catch (e) {
      _message(ParametresApi.erreur(e), erreur: true);
    }
    if (mounted) setState(() => _envoiProfil = false);
  }

  Future<void> _changerMdp() async {
    if (!_cleMdp.currentState!.validate()) return;
    setState(() => _envoiMdp = true);
    try {
      final msg = await ParametresApi.changerMonMotDePasse(_ancien.text, _nouveau.text);
      _ancien.clear();
      _nouveau.clear();
      _confirmation.clear();
      _message(msg);
    } catch (e) {
      _message(ParametresApi.erreur(e), erreur: true);
    }
    if (mounted) setState(() => _envoiMdp = false);
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF2F6FB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Widget _bouton(String texte, bool envoi, VoidCallback onPressed) => SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bleu,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: envoi ? null : onPressed,
          child: envoi
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(texte, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );

  Widget _carte(String titre, List<Widget> enfants) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titre,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: encre)),
              const SizedBox(height: 14),
              ...enfants,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Mon compte', style: TextStyle(color: Colors.white, fontSize: 18)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [bleu, vert])),
        ),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: bleu))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _carte('Mes informations', [
                  if (_moi != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('@${_moi!['username']} · ${_moi!['role_libelle']}',
                          style: const TextStyle(color: gris)),
                    ),
                  TextField(controller: _prenom, decoration: _deco('Prénom')),
                  const SizedBox(height: 12),
                  TextField(controller: _nom, decoration: _deco('Nom')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _tel,
                      keyboardType: TextInputType.phone,
                      decoration: _deco('Téléphone')),
                  const SizedBox(height: 16),
                  _bouton('Enregistrer', _envoiProfil, _enregistrerProfil),
                ]),
                Form(
                  key: _cleMdp,
                  child: _carte('Changer mon mot de passe', [
                    TextFormField(
                      controller: _ancien,
                      obscureText: true,
                      decoration: _deco('Mot de passe actuel'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Obligatoire' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nouveau,
                      obscureText: true,
                      decoration: _deco('Nouveau mot de passe'),
                      validator: (v) {
                        final mdp = v ?? '';
                        if (mdp.length < 8) return '8 caractères minimum';
                        if (RegExp(r'^\d+$').hasMatch(mdp)) return 'Pas uniquement des chiffres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: true,
                      decoration: _deco('Confirmer le nouveau mot de passe'),
                      validator: (v) =>
                          v != _nouveau.text ? 'Les mots de passe ne correspondent pas' : null,
                    ),
                    const SizedBox(height: 16),
                    _bouton('Changer le mot de passe', _envoiMdp, _changerMdp),
                  ]),
                ),
              ],
            ),
    );
  }
}
