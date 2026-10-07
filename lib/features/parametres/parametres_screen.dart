import 'package:flutter/material.dart';

import '../../core/services/permissions_service.dart';
import 'mon_compte_screen.dart';
import 'utilisateurs_screen.dart';

/// Rubrique Paramètres : Utilisateurs (docteur) et Mon compte (tous).
class ParametresScreen extends StatelessWidget {
  const ParametresScreen({super.key});

  static const bleu = Color(0xFF0B47C9);
  static const vert = Color(0xFF08C792);
  static const encre = Color(0xFF0F2547);

  @override
  Widget build(BuildContext context) {
    final docteur = PermissionsService.canGererUtilisateurs;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Paramètres', style: TextStyle(color: Colors.white, fontSize: 18)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [bleu, vert]),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (docteur)
            _Tuile(
              icone: Icons.group_rounded,
              titre: 'Utilisateurs',
              texte: "Comptes de l'équipe, rôles, mots de passe",
              couleur: bleu,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const UtilisateursScreen()),
              ),
            ),
          if (docteur)
            const _Tuile(
              icone: Icons.local_hospital_rounded,
              titre: 'Clinique',
              texte: 'Bientôt disponible',
              couleur: Colors.grey,
            ),
          _Tuile(
            icone: Icons.person_rounded,
            titre: 'Mon compte',
            texte: 'Mes informations et mon mot de passe',
            couleur: vert,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const MonCompteScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tuile extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String texte;
  final Color couleur;
  final VoidCallback? onTap;

  const _Tuile({
    required this.icone,
    required this.titre,
    required this.texte,
    required this.couleur,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        enabled: onTap != null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icone, color: couleur),
        ),
        title: Text(
          titre,
          style: const TextStyle(fontWeight: FontWeight.w700, color: ParametresScreen.encre),
        ),
        subtitle: Text(texte),
        trailing: onTap != null ? const Icon(Icons.chevron_right_rounded) : null,
      ),
    );
  }
}
