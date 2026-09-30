enum UserRole {
  superAdmin, // Madamel / Super Admin (Dashboard complet)
  doctor,     // Docteur (Dashboard complet)
  assistant;  // Assistant (Dashboard restreint)

  static UserRole fromString(String role) {
    switch (role.toUpperCase()) {
      case 'SUPER_ADMIN':
      case 'ADMIN':
        return UserRole.superAdmin;
      case 'DOCTOR':
      case 'DOCTEUR':
        return UserRole.doctor;
      case 'ASSISTANT':
      default:
        return UserRole.assistant;
    }
  }
}