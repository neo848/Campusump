# ============================================================
#  WiFi Watchdog - Campus Connecte
#  Verifie si le WiFi est connecte et reconnecte si necessaire
# ============================================================

$WIFI_NAME     = "Campus Connecte"
$CHECK_INTERVAL = 30    # secondes entre chaque verification
$LOG_FILE      = "$PSScriptRoot\wifi_watchdog.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Write-Host $line
    Add-Content -Path $LOG_FILE -Value $line
}

function Get-WifiStatus {
    $profile = netsh wlan show interfaces |
               Select-String -Pattern "SSID\s*:\s*(.+)" |
               Select-Object -First 1
    $status  = netsh wlan show interfaces |
               Select-String -Pattern "State\s*:\s*(.+)" |
               Select-Object -First 1

    $connectedSSID = if ($profile)  { $profile.Matches.Groups[1].Value.Trim() }  else { "" }
    $state         = if ($status)   { $status.Matches.Groups[1].Value.Trim() }   else { "disconnected" }

    return @{
        SSID  = $connectedSSID
        State = $state
    }
}

function Connect-Wifi {
    param([string]$ProfileName)
    Write-Log "Tentative de connexion au reseau : $ProfileName"
    $result = netsh wlan connect name="$ProfileName" 2>&1
    Write-Log "Resultat : $result"
    Start-Sleep -Seconds 5

    # Verification apres connexion
    $status = Get-WifiStatus
    if ($status.SSID -eq $ProfileName -and $status.State -like "*connected*") {
        Write-Log "✅ Connexion reussie a '$ProfileName'"
        return $true
    } else {
        Write-Log "❌ Echec de la connexion a '$ProfileName'"
        return $false
    }
}

# ============================================================
#  BOUCLE PRINCIPALE
# ============================================================
Write-Log "=== WiFi Watchdog demarre (reseau cible : '$WIFI_NAME') ==="

while ($true) {
    $status = Get-WifiStatus

    if ($status.SSID -eq $WIFI_NAME -and $status.State -like "*connected*") {
        Write-Log "✅ WiFi OK - Connecte a '$WIFI_NAME'"
    }
    else {
        Write-Log "⚠️  WiFi DOWN - SSID actuel: '$($status.SSID)' | Etat: '$($status.State)'"
        $success = Connect-Wifi -ProfileName $WIFI_NAME

        if (-not $success) {
            Write-Log "🔄 Nouvel essai dans $CHECK_INTERVAL secondes..."
        }
    }

    Start-Sleep -Seconds $CHECK_INTERVAL
}
