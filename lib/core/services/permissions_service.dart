// lib/core/services/permissions_service.dart
// ── Centralise les droits selon le rôle stocké dans le token JWT ─────────────

import 'auth_service.dart';

enum UserRole { docteur, assistant, pharmacien, inconnu }

class PermissionsService {
  static UserRole? _role;

  // ── Initialisation (à appeler au démarrage, après login) ──────────────────
  static Future<void> init() async {
    final roleStr = await AuthService.getRole();
    _role = _parseRole(roleStr);
  }

  static UserRole _parseRole(String? r) {
    switch (r?.toUpperCase()) {
      case 'DOCTEUR':
        return UserRole.docteur;
      case 'ASSISTANT':
        return UserRole.assistant;
      case 'PHARMACIEN':
        return UserRole.pharmacien;
      default:
        return UserRole.inconnu;
    }
  }

  static bool get isDocteur => _role == UserRole.docteur;
  static bool get isEmploye => _role == UserRole.assistant || _role == UserRole.pharmacien;

  // ── DASHBOARD ─────────────────────────────────────────────────────────────
  static bool get canSeeValeurStock => isDocteur;

  // ── CLIENTS / ANIMAUX ─────────────────────────────────────────────────────
  static bool get canDeleteClient => isDocteur;
  static bool get canDeleteAnimal => isDocteur;
  static bool get canExportClients => isDocteur;

  // ── CONSULTATIONS ─────────────────────────────────────────────────────────
  static bool get canTerminerConsultation => isDocteur;
  static bool get canGererOrdonnance => isDocteur;
  static bool get canDeleteConsultation => isDocteur;

  // ── PARAMÈTRES ───────────────────────────────────────────────────────────
  static bool get canGererUtilisateurs => isDocteur;

  // ── PHARMACIE ─────────────────────────────────────────────────────────────
  static bool get canEditMedicament => isDocteur;
  static bool get canDeleteMedicament => isDocteur;
  static bool get canExportPharmacie => isDocteur;

  // ── VENTES ───────────────────────────────────────────────────────────────
  static bool get canExportVentes => isDocteur;

  // ── CAISSE ───────────────────────────────────────────────────────────────
  static bool get canVoirCaisse => isDocteur;

  // ── FOURNISSEURS ─────────────────────────────────────────────────────────
  static bool get canEditFournisseur => isDocteur;

  // ── EXPORTS (général) ────────────────────────────────────────────────────
  static bool get canExport => isDocteur;
}
