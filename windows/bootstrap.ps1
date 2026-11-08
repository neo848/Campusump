# Installation Windows depuis le depot public, sans lancement de l'assistant Wi-Fi.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$repository = 'neo848/Campusump'
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$staging = Join-Path $temporaryRoot ('campuse-install-' + [guid]::NewGuid().ToString())
try {
    $revision = (Invoke-RestMethod -Uri "https://api.github.com/repos/$repository/commits/main" -Headers @{'User-Agent'='campuse-installer'}).sha
    if ($revision -notmatch '^[a-f0-9]{40}$') { throw 'Revision GitHub invalide.' }
    $null = New-Item -ItemType Directory -Path $staging
    foreach ($file in @('Installer_Campus.ps1', 'campus_wifi.ps1', 'Lancer_Campus_Wifi.bat', 'campus_config.json', 'Wi-Fi-Campus Connecte.xml')) {
        $name = [Uri]::EscapeDataString($file)
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/$repository/$revision/windows/$name" -OutFile (Join-Path $staging $file)
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $staging 'Installer_Campus.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Installation echouee.' }
} catch {
    Write-Error ('Installation impossible (depot public requis) : ' + $_.Exception.Message)
} finally {
    $resolved = [IO.Path]::GetFullPath($staging)
    $boundary = $temporaryRoot.TrimEnd('\') + '\'
    if (!$resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Chemin temporaire inattendu.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
