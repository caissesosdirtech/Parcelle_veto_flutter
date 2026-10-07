import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/permissions_service.dart';
import '../auth/login_screen.dart';
import 'mon_compte_screen.dart';
import 'parametres_api.dart';
import 'utilisateurs_screen.dart';

/// Rubrique Paramètres, organisée en sections :
/// profil en en-tête · Mon compte · Administration (docteur) · Application.
class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  static const bleu = Color(0xFF0B47C9);
  static const bleuClair = Color(0xFF0A7BD6);
  static const vert = Color(0xFF08C792);
  static const encre = Color(0xFF0F2547);
  static const gris = Color(0xFF6B7A90);
  static const fond = Color(0xFFF4F7FB);

  String _nom = '';
  String _role = '';
  String _identifiant = '';

  @override
  void initState() {
    super.initState();
    _chargerProfil();
  }

  Future<void> _chargerProfil() async {
    // Affichage immédiat avec ce qui est en mémoire, puis le nom complet
    final identifiant = await AuthService.getUsername() ?? '';
    if (mounted) setState(() => _identifiant = identifiant);
    try {
      final moi = await ParametresApi.monCompte();
      if (!mounted) return;
      setState(() {
        _nom = (moi['nom_complet'] ?? '').toString();
        _role = (moi['role_libelle'] ?? '').toString();
        _identifiant = (moi['username'] ?? identifiant).toString();
      });
    } catch (_) {
      // Hors ligne : on garde l'identifiant seul
    }
  }

  Future<void> _ouvrir(Widget ecran) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ecran));
    _chargerProfil(); // le nom a pu changer dans « Mon compte »
  }

  Future<void> _deconnecter() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez saisir à nouveau votre mot de passe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final docteur = PermissionsService.canGererUtilisateurs;
    return Scaffold(
      backgroundColor: fond,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 190,
            backgroundColor: bleu,
            foregroundColor: Colors.white,
            title: const Text('Paramètres', style: TextStyle(fontSize: 18)),
            flexibleSpace: FlexibleSpaceBar(
              background: _enteteProfil(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _titreSection('Mon compte'),
                _groupe([
                  _ligne(
                    icone: Icons.person_outline_rounded,
                    couleur: bleuClair,
                    titre: 'Mes informations',
                    sousTitre: 'Prénom, nom, téléphone',
                    onTap: () => _ouvrir(const MonCompteScreen()),
                  ),
                  _ligne(
                    icone: Icons.lock_outline_rounded,
                    couleur: const Color(0xFF7C3AED),
                    titre: 'Mot de passe',
                    sousTitre: 'Changer mon mot de passe',
                    onTap: () => _ouvrir(const MonCompteScreen()),
                  ),
                ]),
                if (docteur) ...[
                  _titreSection('Administration'),
                  _groupe([
                    _ligne(
                      icone: Icons.group_outlined,
                      couleur: vert,
                      titre: 'Utilisateurs',
                      sousTitre: "Comptes de l'équipe, rôles, accès",
                      onTap: () => _ouvrir(const UtilisateursScreen()),
                    ),
                    _ligne(
                      icone: Icons.local_hospital_outlined,
                      couleur: const Color(0xFFF59E0B),
                      titre: 'Clinique',
                      sousTitre: 'Coordonnées, documents, notifications',
                      badge: 'Bientôt',
                    ),
                  ]),
                ],
                _titreSection('Application'),
                _groupe([
                  _ligne(
                    icone: Icons.info_outline_rounded,
                    couleur: gris,
                    titre: 'À propos',
                    sousTitre: 'Parcelles Véto · Version 1.0',
                  ),
                  _ligne(
                    icone: Icons.logout_rounded,
                    couleur: const Color(0xFFDC2626),
                    titre: 'Se déconnecter',
                    titreRouge: true,
                    onTap: _deconnecter,
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── En-tête : carte de profil sur le dégradé ──────────────────────────────
  Widget _enteteProfil() {
    final affiche = _nom.isNotEmpty ? _nom : (_identifiant.isNotEmpty ? _identifiant : 'Utilisateur');
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [bleu, bleuClair, vert],
          stops: [0, 0.55, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      alignment: Alignment.bottomLeft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Text(
                affiche[0].toUpperCase(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: bleu),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  affiche,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                if (_identifiant.isNotEmpty)
                  Text(
                    '@$_identifiant',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                if (_role.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _role,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Briques de mise en page ───────────────────────────────────────────────
  Widget _titreSection(String texte) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        child: Text(
          texte.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: gris,
            letterSpacing: 0.8,
          ),
        ),
      );

  /// Plusieurs lignes dans une même carte blanche, séparées par un trait fin.
  Widget _groupe(List<Widget> lignes) {
    final enfants = <Widget>[];
    for (var i = 0; i < lignes.length; i++) {
      if (i > 0) {
        enfants.add(const Divider(height: 1, indent: 64, color: Color(0xFFEEF2F7)));
      }
      enfants.add(lignes[i]);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: encre.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(color: Colors.white, child: Column(children: enfants)),
    );
  }

  Widget _ligne({
    required IconData icone,
    required Color couleur,
    required String titre,
    String? sousTitre,
    String? badge,
    bool titreRouge = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icone, color: couleur, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titreRouge ? const Color(0xFFDC2626) : encre,
                    ),
                  ),
                  if (sousTitre != null) ...[
                    const SizedBox(height: 2),
                    Text(sousTitre, style: const TextStyle(fontSize: 12.5, color: gris)),
                  ],
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                ),
              )
            else if (onTap != null && !titreRouge)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0BCC9)),
          ],
        ),
      ),
    );
  }
}
