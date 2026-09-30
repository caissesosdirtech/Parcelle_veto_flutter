# changer_adresse_serveur.ps1
#
# Remplace l'adresse Railway écrite en dur dans tous les fichiers .dart
# par ApiConfig.baseUrl (lib/core/config/api_config.dart), et ajoute
# l'import nécessaire en haut de chaque fichier modifié.
#
# Utilisation : à la RACINE du projet Flutter (là où se trouve pubspec.yaml)
#     powershell -ExecutionPolicy Bypass -File .\changer_adresse_serveur.ps1

$ErrorActionPreference = "Stop"

if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "Lancez ce script a la racine du projet Flutter (dossier contenant pubspec.yaml)." -ForegroundColor Red
    exit 1
}

$ancienne   = "'https://parcelleveto-thies.up.railway.app/'"
$nouvelle   = "ApiConfig.baseUrl"
$import     = "import 'package:parcelles_veto_flutter/core/config/api_config.dart';"
$configPath = "lib\core\config\api_config.dart"
$utf8       = New-Object System.Text.UTF8Encoding($false)   # UTF-8 sans BOM (garde les accents et emojis)

# 1. (Re)crée le fichier central complet
New-Item -ItemType Directory -Force -Path "lib\core\config" | Out-Null
$config = @"
/// Adresse unique du serveur Django.
///
/// Tous les services de l'application doivent utiliser ApiConfig.baseUrl
/// au lieu d'écrire l'adresse en dur. Pour changer de serveur, on ne
/// modifie qu'ici.
class ApiConfig {
  ApiConfig._();

  /// Adresse du serveur, toujours avec le « / » final.
  static const String baseUrl = 'https://parcellesveto-thies.vet/';
}
"@
[System.IO.File]::WriteAllText((Resolve-Path ".").Path + "\" + $configPath, $config.Replace("`r`n", "`n") + "`n", $utf8)
Write-Host "OK  $configPath" -ForegroundColor Green

# 2. Remplace l'adresse dans tous les autres fichiers .dart
$modifies = 0
Get-ChildItem -Path lib -Recurse -Filter *.dart | ForEach-Object {
    if ($_.FullName.EndsWith("core\config\api_config.dart")) { return }

    $contenu = [System.IO.File]::ReadAllText($_.FullName)
    if (-not $contenu.Contains($ancienne)) { return }

    $contenu = $contenu.Replace($ancienne, $nouvelle)
    if (-not $contenu.Contains($import)) {
        $contenu = $import + "`n" + $contenu
    }
    [System.IO.File]::WriteAllText($_.FullName, $contenu, $utf8)
    $modifies++
    Write-Host "OK  $($_.FullName.Substring((Resolve-Path 'lib').Path.Length - 3))" -ForegroundColor Green
}

Write-Host ""
Write-Host "$modifies fichier(s) modifie(s)." -ForegroundColor Cyan

# 3. Verification : il ne doit plus rester d'adresse Railway
$restes = Get-ChildItem -Path lib -Recurse -Filter *.dart | Select-String -Pattern "railway\.app"
if ($restes) {
    Write-Host ""
    Write-Host "Adresses Railway restantes (a traiter a la main) :" -ForegroundColor Yellow
    $restes | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "Plus aucune adresse Railway dans lib\." -ForegroundColor Green
}