# Installation par utilisateur, sans elevation ni modification reseau.
function Install-CampusApp {
    param(
        [string]$SourceDirectory = $PSScriptRoot,
        [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs\CampusConnecte'),
        [string]$DesktopDirectory = [Environment]::GetFolderPath('DesktopDirectory')
    )
    $ErrorActionPreference = 'Stop'
    $files = @('campus_wifi.ps1', 'personal_account.ps1', 'Lancer_Campus_Wifi.bat', 'Wi-Fi-Campus Connecte.xml', 'campus_config.json')
    foreach ($file in $files) {
        if (!(Test-Path -LiteralPath (Join-Path $SourceDirectory $file) -PathType Leaf)) {
            throw "Fichier manquant : $file. Extrayez tout le ZIP avant de lancer INSTALLER.bat."
        }
    }
    if (!$DesktopDirectory -or !(Test-Path -LiteralPath $DesktopDirectory -PathType Container)) {
        throw 'Le dossier Bureau est introuvable.'
    }
    $null = New-Item -ItemType Directory -Path $InstallDirectory -Force
    foreach ($file in $files) {
        $source = Join-Path $SourceDirectory $file
        $destination = Join-Path $InstallDirectory $file
        # Conserver la configuration locale lors des mises a jour.
        if ($file -eq 'campus_config.json' -and (Test-Path -LiteralPath $destination)) { continue }
        if ([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($destination)) {
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }
        Unblock-File -LiteralPath $destination
    }
    $shell = New-Object -ComObject WScript.Shell
    try {
        $shortcut = $shell.CreateShortcut((Join-Path $DesktopDirectory 'Campus Connecte.lnk'))
        $shortcut.TargetPath = Join-Path $InstallDirectory 'Lancer_Campus_Wifi.bat'
        $shortcut.WorkingDirectory = $InstallDirectory
        $shortcut.Description = 'Assistant Wi-Fi Campus Connecte - UMP'
        $shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,17"
        $shortcut.Save()
    } finally {
        if ($shortcut) { $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut) }
        $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    }
    Write-Host 'Installation terminee !' -ForegroundColor Green
    Write-Host 'Double-cliquez sur Campus Connecte sur votre Bureau pour demarrer.'
    Write-Host 'Au lancement, acceptez la demande Windows pour configurer le Wi-Fi.'
    Write-Host 'Aucun parametre Wi-Fi n''a ete modifie pendant l''installation.'
}

if ($MyInvocation.InvocationName -ne '.') {
    try { Install-CampusApp }
    catch { Write-Host ("Installation impossible : " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
}
