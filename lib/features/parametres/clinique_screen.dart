import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import 'parametres_api.dart';

/// Paramètres › Clinique (docteur) : coordonnées reprises sur les PDF et
/// les reçus, mention des ordonnances, seuil d'alerte de stock et choix
/// des notifications. Le logo se change depuis le site web.
class CliniqueScreen extends StatefulWidget {
  const CliniqueScreen({super.key});

  @override
  State<CliniqueScreen> createState() => _CliniqueScreenState();
}

class _CliniqueScreenState extends State<CliniqueScreen> {
  static const bleu = Color(0xFF0B47C9);
  static const vert = Color(0xFF08C792);
  static const encre = Color(0xFF0F2547);
  static const gris = Color(0xFF6B7A90);

  static const _champs = <String, String>{
    'nom_clinique': 'Nom de la clinique *',
    'sous_titre': 'Sous-titre',
    'adresse': 'Adresse',
    'repere': 'Repère',
    'telephones': 'Téléphones (séparés par « / »)',
    'email': 'E-mail',
    'nom_veterinaire': 'Vétérinaire proposé par défaut',
    'slogan': 'Slogan (bas des rapports de caisse)',
  };

  final _controleurs = {for (final c in _champs.keys) c: TextEditingController()};
  final _mention = TextEditingController();
  final _seuil = TextEditingController();
  final _cle = GlobalKey<FormState>();

  List<Map<String, dynamic>> _notifs = [];
  String? _logoUrl;
  bool _modifiable = false;
  bool _appliquerATous = false;
  bool _loading = true;
  bool _envoi = false;
  String? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    for (final c in _controleurs.values) {
      c.dispose();
    }
    _mention.dispose();
    _seuil.dispose();
    super.dispose();
  }

  void _remplir(Map<String, dynamic> c) {
    for (final e in _controleurs.entries) {
      e.value.text = (c[e.key] ?? '').toString();
    }
    _mention.text = (c['mention_ordonnance'] ?? '').toString();
    _seuil.text = (c['seuil_alerte_defaut'] ?? 5).toString();
    // Le serveur renvoie le chemin du logo ; on le rattache à l'adresse
    // de l'app (toujours en https).
    final chemin = c['logo_chemin']?.toString();
    _logoUrl = chemin == null ? null : ApiConfig.baseUrl + chemin.replaceFirst(RegExp('^/'), '');
    _notifs = [
      for (final n in (c['notifications'] as List? ?? const []))
        Map<String, dynamic>.from(n as Map),
    ];
  }

  Future<void> _charger() async {
    setState(() {
      _loading = true;
      _erreurChargement = null;
    });
    try {
      final r = await ParametresApi.clinique();
      if (!mounted) return;
      setState(() {
        _remplir(Map<String, dynamic>.from(r['clinique'] as Map));
        _modifiable = r['modifiable'] == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreurChargement = ParametresApi.erreur(e);
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

  Future<void> _enregistrer() async {
    if (!_cle.currentState!.validate()) return;
    if (_appliquerATous) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Appliquer à tous ?'),
          content: Text(
              'Le seuil d\'alerte de TOUS les médicaments sera remplacé par ${_seuil.text.trim()}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: bleu, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Appliquer'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _envoi = true);
    try {
      final donnees = <String, dynamic>{
        for (final e in _controleurs.entries) e.key: e.value.text.trim(),
        'mention_ordonnance': _mention.text.trim(),
        'seuil_alerte_defaut': int.tryParse(_seuil.text.trim()) ?? 5,
        'notifications': {
          for (final n in _notifs) n['cle'].toString(): n['actif'] == true,
        },
        'appliquer_seuil_a_tous': _appliquerATous,
      };
      final (clinique, message) = await ParametresApi.enregistrerClinique(donnees);
      if (!mounted) return;
      setState(() {
        _remplir(clinique);
        _appliquerATous = false;
      });
      _message(message);
    } catch (e) {
      _message(ParametresApi.erreur(e), erreur: true);
    }
    if (mounted) setState(() => _envoi = false);
  }

  // ── Briques de mise en page ─────────────────────────────────────────────
  InputDecoration _deco(String label, {String? aide}) => InputDecoration(
        labelText: label,
        helperText: aide,
        helperMaxLines: 2,
        filled: true,
        fillColor: const Color(0xFFF2F6FB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Widget _carte(IconData icone, Color couleur, String titre, List<Widget> enfants) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icone, color: couleur, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(titre,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: encre)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...enfants,
            ],
          ),
        ),
      );

  Widget _logo() {
    final url = _logoUrl;
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F6FB),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(6),
          child: url == null
              ? const Center(child: Text('🐾', style: TextStyle(fontSize: 28)))
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, erreur, pile) =>
                      const Icon(Icons.broken_image_outlined, color: gris),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            url == null
                ? 'Aucun logo. Vous pouvez en ajouter un depuis le site web (Paramètres › Clinique).'
                : 'Logo affiché sur les documents. Pour le changer, passez par le site web.',
            style: const TextStyle(fontSize: 13, color: gris, height: 1.35),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Clinique', style: TextStyle(color: Colors.white, fontSize: 18)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [bleu, vert])),
        ),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: bleu))
          : _erreurChargement != null
              ? _vueErreur()
              : _formulaire(),
    );
  }

  Widget _vueErreur() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: gris),
              const SizedBox(height: 12),
              Text(_erreurChargement!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: _charger, child: const Text('Réessayer')),
            ],
          ),
        ),
      );

  Widget _formulaire() {
    final lectureSeule = !_modifiable;
    return Form(
      key: _cle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (lectureSeule)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Lecture seule : seul le docteur peut modifier ces réglages.',
                  style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
            ),
          _carte(Icons.local_hospital_outlined, const Color(0xFFF59E0B), 'Coordonnées', [
            _logo(),
            const SizedBox(height: 16),
            for (final e in _champs.entries) ...[
              TextFormField(
                controller: _controleurs[e.key],
                readOnly: lectureSeule,
                keyboardType: e.key == 'email'
                    ? TextInputType.emailAddress
                    : e.key == 'telephones'
                        ? TextInputType.phone
                        : TextInputType.text,
                textCapitalization: e.key == 'email'
                    ? TextCapitalization.none
                    : TextCapitalization.sentences,
                decoration: _deco(e.value),
                validator: e.key == 'nom_clinique'
                    ? (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null
                    : null,
              ),
              const SizedBox(height: 12),
            ],
          ]),
          _carte(Icons.description_outlined, bleu, 'Ordonnances', [
            TextFormField(
              controller: _mention,
              readOnly: lectureSeule,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              decoration: _deco('Mention en bas des ordonnances',
                  aide: 'Imprimée en petit sous la signature. Vide = rien.'),
            ),
          ]),
          _carte(Icons.inventory_2_outlined, const Color(0xFF7C3AED), 'Stock', [
            TextFormField(
              controller: _seuil,
              readOnly: lectureSeule,
              keyboardType: TextInputType.number,
              decoration: _deco("Seuil d'alerte par défaut",
                  aide: 'Proposé pour chaque nouveau médicament.'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 0 || n > 10000) return 'Nombre entre 0 et 10 000';
                return null;
              },
            ),
            if (!lectureSeule)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _appliquerATous,
                onChanged: (v) => setState(() => _appliquerATous = v ?? false),
                title: const Text('Appliquer aussi à tous les médicaments existants',
                    style: TextStyle(fontSize: 14)),
              ),
          ]),
          _carte(Icons.notifications_outlined, vert, 'Notifications', [
            for (final n in _notifs)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: n['actif'] == true,
                onChanged: lectureSeule ? null : (v) => setState(() => n['actif'] = v),
                title: Text(n['libelle'].toString(),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 4),
            const Text(
              "Une notification désactivée n'est plus envoyée aux téléphones, "
              'mais reste visible dans la liste des notifications.',
              style: TextStyle(fontSize: 12.5, color: gris),
            ),
          ]),
          if (!lectureSeule)
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: bleu,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _envoi ? null : _enregistrer,
                icon: _envoi
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: const Text('Enregistrer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
        ],
      ),
    );
  }
}
