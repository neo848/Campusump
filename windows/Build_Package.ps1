$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$destination = Join-Path $root 'dist'
$null = New-Item -ItemType Directory -Path $destination -Force
$stage = Join-Path $destination ('package-' + [guid]::NewGuid())
try {
    $null = New-Item -ItemType Directory -Path (Join-Path $stage 'windows') -Force
    foreach ($file in @('INSTALLER.bat', 'LIRE_MOI.txt')) {
        Copy-Item -LiteralPath (Join-Path $root $file) -Destination $stage
    }
    foreach ($file in @('Installer_Campus.ps1', 'campus_wifi.ps1', 'personal_account.ps1', 'Lancer_Campus_Wifi.bat', 'Wi-Fi-Campus Connecte.xml', 'campus_config.json')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $stage 'windows')
    }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath (Join-Path $destination 'Campus-Connecte-Windows.zip') -Force
    Write-Output (Join-Path $destination 'Campus-Connecte-Windows.zip')
} finally {
    $resolved = [IO.Path]::GetFullPath($stage)
    $boundary = [IO.Path]::GetFullPath($destination) + [IO.Path]::DirectorySeparatorChar
    if (!$resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe staging cleanup path' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
