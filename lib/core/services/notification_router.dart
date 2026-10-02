import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../../features/consultations/consultations_screen.dart';
import '../../features/pharmacie/pharmacie_screen.dart';
import '../../features/rendez_vous/rendez_vous_screen.dart';
import '../../screens/vente_detail_bottom_sheet.dart';

/// Ouvre le bon écran quand on appuie sur une notification.
///
/// Les données viennent du serveur (champ `data` de la notification) :
///   - type = vente        → détail de la vente (id)
///   - type = consultation → écran des consultations
///   - type = rdv          → écran des rendez-vous
///   - type = stock        → écran de la pharmacie
///   - autre / inconnu     → le texte complet de la notification
///
/// Si l'app vient d'être lancée par la notification, l'ouverture attend
/// que le tableau de bord soit affiché (après la connexion si besoin).
class NotificationRouter {
  static Map<String, dynamic>? _enAttente;
  static bool _pret = false;

  /// À appeler quand le tableau de bord est affiché.
  static void marquerPret() {
    _pret = true;
    final donnees = _enAttente;
    _enAttente = null;
    if (donnees != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ouvrir(donnees));
    }
  }

  /// À appeler quand le tableau de bord disparaît (déconnexion).
  static void marquerNonPret() => _pret = false;

  /// Point d'entrée : ouvre tout de suite, ou garde pour plus tard.
  static void ouvrir(Map<String, dynamic> donnees) {
    if (_pret && appNavigatorKey.currentState != null) {
      _ouvrir(donnees);
    } else {
      _enAttente = donnees;
    }
  }

  /// Pour les notifications affichées par l'app elle-même (premier plan).
  static void ouvrirDepuisPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decode = jsonDecode(payload);
      if (decode is Map) ouvrir(Map<String, dynamic>.from(decode));
    } catch (e) {
      debugPrint('Notification : payload illisible ($e)');
    }
  }

  static void _ouvrir(Map<String, dynamic> donnees) {
    final navigateur = appNavigatorKey.currentState;
    final ctx = appNavigatorKey.currentContext;
    if (navigateur == null || ctx == null) return;

    final type = (donnees['type'] ?? '').toString();
    final id = (donnees['id'] ?? donnees['consultation_id'] ?? '').toString();

    switch (type) {
      case 'vente':
        final venteId = int.tryParse(id);
        if (venteId != null) {
          showModalBottomSheet(
            context: ctx,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => VenteDetailBottomSheet(
              vente: <String, dynamic>{'id': venteId},
            ),
          );
          return;
        }
        break;
      case 'consultation':
        navigateur.push(MaterialPageRoute<void>(
          builder: (_) => const ConsultationsScreen(),
        ));
        return;
      case 'rdv':
        navigateur.push(MaterialPageRoute<void>(
          builder: (_) => const RendezVousScreen(),
        ));
        return;
      case 'stock':
        navigateur.push(MaterialPageRoute<void>(
          builder: (_) => const PharmacieScreen(),
        ));
        return;
    }

    _afficherTexte(ctx, donnees);
  }

  /// Affiche simplement le titre et le texte complet de la notification.
  static void _afficherTexte(BuildContext ctx, Map<String, dynamic> donnees) {
    final titre = (donnees['titre'] ?? 'Notification').toString();
    final corps = (donnees['corps'] ?? '').toString();
    if (corps.isEmpty && titre == 'Notification') return;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                titre,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F2547),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                corps,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: Color(0xFF4A5A6E),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
