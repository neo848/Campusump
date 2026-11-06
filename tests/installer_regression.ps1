$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
. (Join-Path $root 'windows/Installer_Campus.ps1')
$testRoot = Join-Path $PSScriptRoot ('install-' + [guid]::NewGuid())
$install = Join-Path $testRoot "Utilisateur d'essai !\Application"
$desktop = Join-Path $testRoot 'Bureau OneDrive'
try {
    $null = New-Item -ItemType Directory -Path $desktop -Force
    Install-CampusApp -SourceDirectory (Join-Path $root 'windows') -InstallDirectory $install -DesktopDirectory $desktop
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut((Join-Path $desktop 'Campus Connecte.lnk'))
    if ($shortcut.TargetPath -ne (Join-Path $install 'Lancer_Campus_Wifi.bat')) { throw 'Wrong shortcut target' }
    if ($shortcut.WorkingDirectory -ne $install) { throw 'Wrong working directory' }
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    Set-Content -LiteralPath (Join-Path $install 'campus_config.json') -Value '{"local":true}'
    Install-CampusApp -SourceDirectory (Join-Path $root 'windows') -InstallDirectory $install -DesktopDirectory $desktop
    if ((Get-Content -LiteralPath (Join-Path $install 'campus_config.json') -Raw) -notmatch 'local') { throw 'Configuration overwritten' }
    foreach ($file in @('campus_wifi.ps1', 'personal_account.ps1', 'Lancer_Campus_Wifi.bat', 'Wi-Fi-Campus Connecte.xml')) {
        if ((Get-FileHash -LiteralPath (Join-Path $install $file)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $root "windows/$file" )).Hash) { throw "Copy mismatch: $file" }
    }
    Write-Output 'PASS: installation, actual shortcut, paths with spaces/apostrophe/exclamation, update and configuration preservation. Application not launched.'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $boundary = [IO.Path]::GetFullPath($PSScriptRoot) + [IO.Path]::DirectorySeparatorChar
    if (!$resolved.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
