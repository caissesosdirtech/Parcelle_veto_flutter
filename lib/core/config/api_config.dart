/// Adresse unique du serveur Django.
///
/// Tous les services de l'application doivent utiliser ApiConfig.baseUrl
/// au lieu d'Ã©crire l'adresse en dur. Pour changer de serveur, on ne
/// modifie qu'ici.
class ApiConfig {
  ApiConfig._();

  /// Adresse du serveur, toujours avec le Â« / Â» final.
  static const String baseUrl = 'https://parcellesveto-thies.vet/';
}
