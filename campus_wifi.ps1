<#
================================================================================
    CAMPUS CONNECTE - CONFIGURATEUR IP STATIQUE WINDOWS (UMP OUJDA)
================================================================================
    Ce script resout le probleme de saturation du serveur DHCP du reseau
    "Campus connecte" a l'Universite Mohammed Premier (UMP Oujda).
    Fonctionnalites majeures :
      1. Connexion initiale automatique au Wi-Fi "Campus Connecte".
      2. Choix du compte : Defaut (Campus.fsjeso@ump.ac.ma) ou Personnel.
      3. DNS Google par defaut (8.8.8.8 / 8.8.4.4) + Secours UMP.
      4. Temps de stabilisation etendu (7s) avec negociation ARP progressive.
      5. Test prealable du DHCP en premier lieu.
      6. Scan et ecrasement automatique des parametres IP dans la plage
         jusqu'a trouver une adresse pleinement fonctionnelle (Auto-Troubleshoot).
      7. Restauration du mode DHCP automatique a tout moment.
================================================================================
#>

# Parametrage de l'environnement PowerShell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Campus Connecte - Assistant Reseau UMP"

# ------------------------------------------------------------------------------
# 1. VERIFICATION DE L'ELEVATION ADMINISTRATEUR (SECURITE)
# ------------------------------------------------------------------------------
function Ensure-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host ""
        Write-Host " [!] ATTENTION: Privileges administrateur requis pour configurer les cartes reseau." -ForegroundColor Yellow
        Write-Host " [*] Relance automatique avec elevation de privileges (UAC)..." -ForegroundColor Cyan
        Write-Host ""
        Start-Sleep -Seconds 1

        try {
            $scriptPath = $PSCommandPath
            if (-not $scriptPath) {
                $scriptPath = "$PSScriptRoot\campus_wifi.ps1"
            }
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        } catch {
            Write-Host " [ERREUR] Impossible de demander l'elevation. Veuillez executer en tant qu'administrateur." -ForegroundColor Red
            Pause
        }
        exit
    }
}

# ------------------------------------------------------------------------------
# 2. CHARGEMENT DE LA CONFIGURATION ET PROFILS FACULTES
# ------------------------------------------------------------------------------
$ConfigFilePath = Join-Path -Path $PSScriptRoot -ChildPath "campus_config.json"
$Config = $null

if (Test-Path $ConfigFilePath) {
    try {
        $jsonRaw = Get-Content -Path $ConfigFilePath -Raw -Encoding UTF8
        $Config = $jsonRaw | ConvertFrom-Json
    } catch {
        Write-Host " [!] Avertissement: Impossible de parser campus_config.json. Utilisation des valeurs integrees." -ForegroundColor Yellow
    }
}

$DefaultProfiles = @(
    [PSCustomObject]@{
        id = "fso"
        name = "FSO Bibliotheque (Faculte des Sciences - Groupe)"
        gateway = "100.121.0.1"
        subnet_mask = "255.255.0.0"
        cidr = 16
        active_octet3_min = 192
        active_octet3_max = 193
        active_octet4_min = 15
        active_octet4_max = 245
        description = "Plage 100.121.192.x-193.x observee a la Bibliotheque FSO / Zone Groupe. ATTENTION: IP differente de FSO Solo (194.x)."
    },
    [PSCustomObject]@{
        id = "fso_solo"
        name = "FSO Solo (Faculte des Sciences - Salles Solo)"
        gateway = "100.121.0.1"
        subnet_mask = "255.255.0.0"
        cidr = 16
        active_octet3_min = 194
        active_octet3_max = 194
        active_octet4_min = 15
        active_octet4_max = 245
        description = "Plage 100.121.194.x observee aux Salles Individuelles FSO Solo. ATTENTION: IP differente de FSO Biblio Groupe (192-193.x)."
    },
    [PSCustomObject]@{
        id = "fso_master"
        name = "FSO Master (Faculte des Sciences - Master / Amphis)"
        gateway = "100.121.0.1"
        subnet_mask = "255.255.0.0"
        cidr = 16
        active_octet3_min = 195
        active_octet3_max = 196
        active_octet4_min = 15
        active_octet4_max = 245
        description = "Plage 100.121.195.x-196.x observee au Master FSO / Amphis (ex: 100.121.195.100, 100.121.196.96)"
    },
    [PSCustomObject]@{
        id = "qanon"
        name = "Qanon / Droit (FSJESO - Amphis / Limen)"
        gateway = "100.90.144.1"
        subnet_mask = "255.255.240.0"
        cidr = 20
        active_octet3_min = 145
        active_octet3_max = 149
        active_octet4_min = 15
        active_octet4_max = 245
        description = "Plage 100.90.144.0/20 observee a la Faculte de Droit / Qanon"
    },
    [PSCustomObject]@{
        id = "fsjeso"
        name = "FSJESO (Economie & Gestion / Administration)"
        gateway = "100.90.144.1"
        subnet_mask = "255.255.240.0"
        cidr = 20
        active_octet3_min = 144
        active_octet3_max = 144
        active_octet4_min = 15
        active_octet4_max = 245
        description = "Plage 100.90.144.0/20 observee a la FSJESO Economie"
    },
    [PSCustomObject]@{
        id = "ensao"
        name = "ENSAO (Ecole Nationale des Sciences Appliquees)"
        gateway = "100.96.160.1"
        subnet_mask = "255.255.224.0"
        cidr = 19
        active_octet3_min = 180
        active_octet3_max = 189
        active_octet4_min = 15
        active_octet4_max = 245
        description = "Plage 100.96.160.0/19 observee a l'ENSAO (100.96.187.x)"
    }
)

# DNS Google par defaut
$DnsPrimary = "8.8.8.8"
$DnsSecondary = "8.8.4.4"
$DnsFallback = "100.127.255.70"

# ------------------------------------------------------------------------------
# 3. HELPER API WLAN (AUTHENTIFICATION INITIALE 802.1X / EAP-TTLS)
# ------------------------------------------------------------------------------
function Initialize-WlanHelper {
    if (-not ([System.Management.Automation.PSTypeName]'WlanHelper').Type) {
        $source = @"
using System;
using System.Runtime.InteropServices;

public class WlanHelper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct WLAN_INTERFACE_INFO {
        public Guid InterfaceGuid;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string strInterfaceDescription;
        public int isState;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WLAN_INTERFACE_INFO_LIST {
        public uint dwNumberOfItems;
        public uint dwIndex;
        public WLAN_INTERFACE_INFO[] InterfaceInfo;

        public WLAN_INTERFACE_INFO_LIST(IntPtr pList) {
            dwNumberOfItems = (uint)Marshal.ReadInt32(pList);
            dwIndex = (uint)Marshal.ReadInt32(pList, 4);
            InterfaceInfo = new WLAN_INTERFACE_INFO[dwNumberOfItems];
            for (int i = 0; i < dwNumberOfItems; i++) {
                IntPtr pItem = new IntPtr(pList.ToInt64() + 8 + (i * Marshal.SizeOf(typeof(WLAN_INTERFACE_INFO))));
                InterfaceInfo[i] = (WLAN_INTERFACE_INFO)Marshal.PtrToStructure(pItem, typeof(WLAN_INTERFACE_INFO));
            }
        }
    }

    [DllImport("wlanapi.dll")]
    public static extern int WlanOpenHandle(uint dwClientVersion, IntPtr pReserved, out uint pdwNegotiatedVersion, out IntPtr phClientHandle);

    [DllImport("wlanapi.dll")]
    public static extern int WlanCloseHandle(IntPtr hClientHandle, IntPtr pReserved);

    [DllImport("wlanapi.dll")]
    public static extern int WlanEnumInterfaces(IntPtr hClientHandle, IntPtr pReserved, out IntPtr ppInterfaceList);

    [DllImport("wlanapi.dll")]
    public static extern void WlanFreeMemory(IntPtr pMemory);

    [DllImport("wlanapi.dll", CharSet = CharSet.Unicode)]
    public static extern int WlanSetProfileEapXmlUserData(
        IntPtr hClientHandle,
        ref Guid pInterfaceGuid,
        string strProfileName,
        uint dwFlags,
        string strEapXmlUserData,
        IntPtr pReserved
    );

    public static int SetEapCredentials(string profileName, string userXml) {
        IntPtr hClient;
        uint negVersion;
        int ret = WlanOpenHandle(2, IntPtr.Zero, out negVersion, out hClient);
        if (ret != 0) return ret;

        try {
            IntPtr pList;
            ret = WlanEnumInterfaces(hClient, IntPtr.Zero, out pList);
            if (ret != 0) return ret;

            try {
                WLAN_INTERFACE_INFO_LIST list = new WLAN_INTERFACE_INFO_LIST(pList);
                if (list.dwNumberOfItems == 0) return -1;
                Guid ifaceGuid = list.InterfaceInfo[0].InterfaceGuid;
                return WlanSetProfileEapXmlUserData(hClient, ref ifaceGuid, profileName, 0, userXml, IntPtr.Zero);
            } finally {
                WlanFreeMemory(pList);
            }
        } finally {
            WlanCloseHandle(hClient, IntPtr.Zero);
        }
    }
}
"@
        try {
            Add-Type -TypeDefinition $source -ErrorAction SilentlyContinue
        } catch { }
    }
}

function Set-CampusCredentialsInWindows([string]$username, [string]$password) {
    Initialize-WlanHelper

    $profileXmlPath = Join-Path $PSScriptRoot "Wi-Fi-Campus Connecte.xml"
    $profiles = netsh wlan show profiles
    if ($profiles -notmatch "Campus Connecte") {
        if (Test-Path $profileXmlPath) {
            Write-Host " [*] Creation du profil Wi-Fi 'Campus Connecte'..." -ForegroundColor Cyan
            & netsh wlan add profile filename="$profileXmlPath" user=all | Out-Null
        }
    }

    $eapXml = @"
<EapHostUserCredentials xmlns="http://www.microsoft.com/provisioning/EapHostUserCredentials"
  xmlns:eapCommon="http://www.microsoft.com/provisioning/EapCommon">
  <EapMethod>
    <eapCommon:Type>21</eapCommon:Type>
    <eapCommon:VendorId>0</eapCommon:VendorId>
    <eapCommon:VendorType>0</eapCommon:VendorType>
    <eapCommon:AuthorId>311</eapCommon:AuthorId>
  </EapMethod>
  <Credentials xmlns="http://www.microsoft.com/provisioning/EapHostUserCredentials">
    <EapTtls xmlns="http://www.microsoft.com/provisioning/EapTtlsUserPropertiesV1">
      <Username>$username</Username>
      <Password>$password</Password>
    </EapTtls>
  </Credentials>
</EapHostUserCredentials>
"@

    try {
        if (([System.Management.Automation.PSTypeName]'WlanHelper').Type) {
            $ret = [WlanHelper]::SetEapCredentials("Campus Connecte", $eapXml)
            if ($ret -eq 0) {
                Write-Host " [OK] Identifiants 802.1X configures automatiquement dans Windows !" -ForegroundColor Green
            }
        }
    } catch { }

    try {
        Set-Clipboard -Value $password -ErrorAction SilentlyContinue
        Write-Host " [*] Note : Le mot de passe a aussi ete copie dans votre presse-papiers." -ForegroundColor DarkGray
    } catch { }
}

function Connect-CampusWifiInitial([string]$adapterName) {
    Show-Banner
    Write-Host " ================= CONNEXION INITIALE AU WI-FI CAMPUS ==================" -ForegroundColor Cyan
    Write-Host "  Cette etape vous connecte au reseau et configure votre compte." -ForegroundColor Gray
    Show-Separator
    Write-Host ""
    Write-Host " Quel compte souhaitez-vous utiliser pour vous connecter ?" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1] Compte par defaut UMP (Recommande - Avis Bibliotheque) :" -ForegroundColor Green
    Write-Host "      Identifiant  : Campus.fsjeso@ump.ac.ma" -ForegroundColor Yellow
    Write-Host "      Mot de passe : Fsjeso2026 (F majuscule)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [2] Mon propre compte etudiant personnel UMP" -ForegroundColor Cyan
    Write-Host "      Saisir votre adresse institutionnelle et votre mot de passe" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] Passer cette etape (deja associe au Wi-Fi)" -ForegroundColor DarkGray
    Write-Host ""
    Show-Separator

    $choice = Read-Host " Votre choix [1]"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

    $userEmail = "Campus.fsjeso@ump.ac.ma"
    $userPass = "Fsjeso2026"

    if ($choice -eq "2") {
        Write-Host ""
        $userEmail = (Read-Host " Entrez votre email etudiant UMP (ex: nom.prenom@ump.ac.ma)").Trim()
        $userPass = (Read-Host " Entrez votre mot de passe").Trim()
    } elseif ($choice -eq "3") {
        return
    }

    Write-Host ""
    Write-Host " [*] Configuration des identifiants pour : $userEmail" -ForegroundColor Cyan
    Set-CampusCredentialsInWindows -username $userEmail -password $userPass

    Write-Host " [*] Connexion au point d'acces 'Campus Connecte'..." -ForegroundColor Cyan
    & netsh wlan connect name="Campus Connecte" interface="$adapterName" | Out-Null

    Write-Host " [*] Attente de la synchronisation Wi-Fi (5s)..." -NoNewline -ForegroundColor Gray
    for ($i = 0; $i -lt 5; $i++) {
        Start-Sleep -Seconds 1
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host " [OK] Ordre de connexion Wi-Fi applique !" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

# ------------------------------------------------------------------------------
# 4. FONCTIONS D'AFFICHAGE ET IHM
# ------------------------------------------------------------------------------
function Show-Banner {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "             CAMPUS CONNECTE - ASSISTANT IP STATIQUE (UMP OUJDA)                " -ForegroundColor White
    Write-Host "   Contournement de la saturation DHCP pour 'Campus connecte' (FSO, Qanon, ENSAO)" -ForegroundColor Gray
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Separator {
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# 5. FONCTIONS DE CALCUL IP & VERIFICATION SOUS-RESEAU (SECURITE)
# ------------------------------------------------------------------------------
function Test-IsValidIPv4([string]$ip) {
    if ([string]::IsNullOrWhiteSpace($ip)) { return $false }
    $parsedIP = $null
    if ([System.Net.IPAddress]::TryParse($ip, [ref]$parsedIP)) {
        if ($parsedIP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
            $bytes = $parsedIP.GetAddressBytes()
            if ($bytes[0] -eq 0 -or $bytes[0] -eq 127) { return $false }
            return $true
        }
    }
    return $false
}

function Get-SubnetCalculation([string]$gateway, [string]$subnetMask) {
    try {
        $gwBytes = ([System.Net.IPAddress]::Parse($gateway)).GetAddressBytes()
        $maskBytes = ([System.Net.IPAddress]::Parse($subnetMask)).GetAddressBytes()

        $netBytes = [byte[]]@(0, 0, 0, 0)
        $bcastBytes = [byte[]]@(0, 0, 0, 0)

        for ($i = 0; $i -lt 4; $i++) {
            $netBytes[$i] = [byte]($gwBytes[$i] -band $maskBytes[$i])
            $wildcard = [byte](255 -bxor $maskBytes[$i])
            $bcastBytes[$i] = [byte]($netBytes[$i] -bor $wildcard)
        }

        $minHostBytes = [byte[]]$netBytes.Clone()
        $minHostBytes[3] = [byte]($minHostBytes[3] + 1)

        $maxHostBytes = [byte[]]$bcastBytes.Clone()
        $maxHostBytes[3] = [byte]($maxHostBytes[3] - 1)

        return [PSCustomObject]@{
            Network   = [System.Net.IPAddress]::new($netBytes).ToString()
            Broadcast = [System.Net.IPAddress]::new($bcastBytes).ToString()
            MinHost   = [System.Net.IPAddress]::new($minHostBytes).ToString()
            MaxHost   = [System.Net.IPAddress]::new($maxHostBytes).ToString()
            NetBytes  = $netBytes
            MaskBytes = $maskBytes
            BcastBytes= $bcastBytes
        }
    } catch {
        return $null
    }
}

function Test-IPIsInSubnet([string]$candidateIP, [string]$gateway, [string]$subnetMask) {
    if (-not (Test-IsValidIPv4 $candidateIP)) { return $false }
    try {
        $calc = Get-SubnetCalculation -gateway $gateway -subnetMask $subnetMask
        if ($null -eq $calc) { return $false }

        $ipBytes = ([System.Net.IPAddress]::Parse($candidateIP)).GetAddressBytes()

        for ($i = 0; $i -lt 4; $i++) {
            if ([byte]($ipBytes[$i] -band $calc.MaskBytes[$i]) -ne $calc.NetBytes[$i]) {
                return $false
            }
        }

        $ipStr = [System.Net.IPAddress]::new($ipBytes).ToString()
        if ($ipStr -eq $gateway -or $ipStr -eq $calc.Network -or $ipStr -eq $calc.Broadcast) {
            return $false
        }

        return $true
    } catch {
        return $false
    }
}

function Get-RandomIPForProfile($profile) {
    $gwParts = $profile.gateway.Split('.')
    $octet1 = [int]$gwParts[0]
    $octet2 = [int]$gwParts[1]

    $oct3Min = if ($profile.active_octet3_min) { $profile.active_octet3_min } else { [int]$gwParts[2] }
    $oct3Max = if ($profile.active_octet3_max) { $profile.active_octet3_max } else { [int]$gwParts[2] }
    $oct4Min = if ($profile.active_octet4_min) { $profile.active_octet4_min } else { 20 }
    $oct4Max = if ($profile.active_octet4_max) { $profile.active_octet4_max } else { 240 }

    $randomOctet3 = Get-Random -Minimum $oct3Min -Maximum ($oct3Max + 1)
    $randomOctet4 = Get-Random -Minimum $oct4Min -Maximum ($oct4Max + 1)

    $candidate = "$octet1.$octet2.$randomOctet3.$randomOctet4"
    if ($candidate -eq $profile.gateway) {
        $candidate = "$octet1.$octet2.$randomOctet3." + ($randomOctet4 + 2)
    }
    return $candidate
}

function Find-FreeCandidateIP($profile, [int]$maxAttempts = 5) {
    for ($i = 0; $i -lt $maxAttempts; $i++) {
        $cand = Get-RandomIPForProfile $profile
        $ping = Test-Connection -ComputerName $cand -Count 1 -Quiet -ErrorAction SilentlyContinue
        if (-not $ping) {
            return $cand
        }
    }
    return Get-RandomIPForProfile $profile
}

# ------------------------------------------------------------------------------
# 6. GESTION DES CARTES RESEAU (ADAPTERS)
# ------------------------------------------------------------------------------
function Get-WifiAdapterName {
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue

    $wifi = $adapters | Where-Object {
        $_.Name -like "*Wi-Fi*" -or
        $_.InterfaceDescription -like "*Wireless*" -or
        $_.InterfaceDescription -like "*Wi-Fi*" -or
        $_.InterfaceDescription -like "*802.11*"
    } | Select-Object -First 1

    if ($wifi) {
        return $wifi.Name
    }

    $anyWifi = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Wi-Fi*" } | Select-Object -First 1
    if ($anyWifi) {
        return $anyWifi.Name
    }

    return "Wi-Fi"
}

function Show-CurrentAdapterStatus([string]$adapterName) {
    Write-Host "[ Carte Reseau Active : " -NoNewline -ForegroundColor White
    Write-Host "$adapterName" -NoNewline -ForegroundColor Cyan
    Write-Host " ]" -ForegroundColor White

    try {
        $netIP = Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
        $routes = Get-NetRoute -InterfaceAlias $adapterName -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
        $dns = Get-DnsClientServerAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue

        $ipMode = "Inconnu"
        $ipInterface = Get-NetIPInterface -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($ipInterface) {
            $ipMode = if ($ipInterface.Dhcp -eq "Enabled") { "DHCP (Automatique)" } else { "Statique (Manuel)" }
        }

        $currentIP = if ($netIP) { $netIP.IPAddress } else { "Non assignee" }
        $currentGW = if ($routes) { $routes.NextHop } else { "Non configuree" }
        $currentDNS = if ($dns -and $dns.ServerAddresses) { ($dns.ServerAddresses -join ", ") } else { "Automatique" }

        Write-Host "  * Mode d'adressage : " -NoNewline -ForegroundColor DarkGray
        Write-Host "$ipMode" -ForegroundColor $(if ($ipMode -like "*Statique*") { "Yellow" } else { "Green" })

        Write-Host "  * Adresse IPv4     : " -NoNewline -ForegroundColor DarkGray
        Write-Host "$currentIP" -ForegroundColor $(if ($currentIP -ne "Non assignee") { "Green" } else { "Red" })

        Write-Host "  * Passerelle (GW)  : " -NoNewline -ForegroundColor DarkGray
        Write-Host "$currentGW" -ForegroundColor Gray

        Write-Host "  * Serveurs DNS     : " -NoNewline -ForegroundColor DarkGray
        Write-Host "$currentDNS (Google 8.8.8.8)" -ForegroundColor Gray
    } catch {
        Write-Host "  (Informations d'interface non disponibles actuellement)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ------------------------------------------------------------------------------
# 7. CONFIGURATION RESEAU (NETSH & POWERSHELL)
# ------------------------------------------------------------------------------
function Apply-StaticConfiguration([string]$adapterName, [string]$ip, [string]$mask, [string]$gateway, [string]$primaryDns, [string]$secondaryDns, [string]$fallbackDns) {
    Write-Host ""
    Write-Host " [*] Ecrasement et application de la configuration statique..." -ForegroundColor Cyan
    Write-Host "     - Carte reseau : $adapterName" -ForegroundColor Gray
    Write-Host "     - Adresse IP   : $ip" -ForegroundColor Yellow
    Write-Host "     - Masque       : $mask" -ForegroundColor Gray
    Write-Host "     - Passerelle   : $gateway" -ForegroundColor Gray
    Write-Host "     - DNS Primaire : $primaryDns (Google)" -ForegroundColor Green
    Write-Host "     - DNS Second.  : $secondaryDns (Google)" -ForegroundColor Green

    try {
        # 1. Configuration IP Statique + Passerelle
        $procIP = Start-Process -FilePath "netsh.exe" -ArgumentList @("interface", "ipv4", "set", "address", "name=$adapterName", "source=static", "address=$ip", "mask=$mask", "gateway=$gateway", "gwmetric=1") -Wait -PassThru -NoNewWindow
        
        # 2. Configuration DNS Google par defaut
        $procDNS1 = Start-Process -FilePath "netsh.exe" -ArgumentList @("interface", "ipv4", "set", "dnsservers", "name=$adapterName", "source=static", "address=$primaryDns", "register=primary", "validate=no") -Wait -PassThru -NoNewWindow

        if ($secondaryDns) {
            $null = Start-Process -FilePath "netsh.exe" -ArgumentList @("interface", "ipv4", "add", "dnsservers", "name=$adapterName", "address=$secondaryDns", "index=2", "validate=no") -Wait -PassThru -NoNewWindow
        }

        if ($fallbackDns) {
            $null = Start-Process -FilePath "netsh.exe" -ArgumentList @("interface", "ipv4", "add", "dnsservers", "name=$adapterName", "address=$fallbackDns", "index=3", "validate=no") -Wait -PassThru -NoNewWindow
        }

        # Nettoyage des caches ARP et DNS
        $null = Start-Process -FilePath "netsh.exe" -ArgumentList @("interface", "ipv4", "delete", "arpcache") -Wait -PassThru -NoNewWindow 2>$null
        $null = & ipconfig /flushdns

        return $true
    } catch {
        Write-Host " [ERREUR] Echec lors de la configuration: $_" -ForegroundColor Red
        return $false
    }
}

function Apply-DHCPConfiguration([string]$adapterName) {
    Write-Host ""
    Write-Host " [*] Reinitialisation de la carte en mode DHCP (Automatique)..." -ForegroundColor Cyan
    Write-Host "     - Carte reseau : $adapterName" -ForegroundColor Gray

    try {
        $null = Start-Process -FilePath "netsh.exe" -ArgumentList @("interface", "ipv4", "set", "address", "name=$adapterName", "source=dhcp") -Wait -PassThru -NoNewWindow

        $null = Start-Process -FilePath "netsh.exe" -ArgumentList @("interface", "ipv4", "set", "dnsservers", "name=$adapterName", "source=dhcp") -Wait -PassThru -NoNewWindow

        Write-Host " [*] Renouvellement du bail DHCP (ipconfig /renew)..." -ForegroundColor DarkGray
        $null = & ipconfig /renew "$adapterName" 2>$null
        $null = & ipconfig /flushdns

        Write-Host " [OK] Mode DHCP restaure avec succes !" -ForegroundColor Green
        Start-Sleep -Seconds 2
        return $true
    } catch {
        Write-Host " [ERREUR] Impossible de restaurer le DHCP: $_" -ForegroundColor Red
        return $false
    }
}

# ------------------------------------------------------------------------------
# 8. TESTS PROGRESSIFS AVEC TEMPS DE STABILISATION ETENDU
# ------------------------------------------------------------------------------
function Test-ConnectionWithProgress([string]$gateway, [int]$waitSeconds = 7) {
    Write-Host " [*] Stabilisation du lien Wi-Fi et negociation ARP ($waitSeconds`s) " -NoNewline -ForegroundColor DarkGray
    for ($i = 0; $i -lt $waitSeconds; $i++) {
        Start-Sleep -Seconds 1
        Write-Host "." -NoNewline -ForegroundColor DarkGray
    }
    Write-Host " [Pret]" -ForegroundColor Green

    # Ping progressif (tente 3 fois pour absorber la latence initiale)
    $pingOk = $false
    for ($p = 1; $p -le 3; $p++) {
        $res = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($res) {
            $pingOk = $true
            break
        }
        Start-Sleep -Milliseconds 800
    }

    if (-not $pingOk) {
        $pingOk = Test-Connection -ComputerName "1.1.1.1" -Count 1 -Quiet -ErrorAction SilentlyContinue
    }

    return $pingOk
}

function Test-ConnectionDiagnostic([string]$gateway) {
    Write-Host ""
    Write-Host " ===================== TEST DE CONNECTIVITE =====================" -ForegroundColor Cyan
    Write-Host " [*] Diagnostic reseau en cours..." -ForegroundColor Gray

    $gwOk = $false
    if ($gateway -and (Test-IsValidIPv4 $gateway)) {
        Write-Host " [1/3] Ping Passerelle Campus ($gateway)... " -NoNewline -ForegroundColor Gray
        $pingGw = Test-Connection -ComputerName $gateway -Count 2 -Quiet -ErrorAction SilentlyContinue
        if ($pingGw) {
            Write-Host "[SUCCES - JOIGNABLE]" -ForegroundColor Green
            $gwOk = $true
        } else {
            Write-Host "[ECHEC - INJOIGNABLE]" -ForegroundColor Red
        }
    } else {
        Write-Host " [1/3] Passerelle non configuree (DHCP ou hors ligne)" -ForegroundColor Yellow
    }

    Write-Host " [2/3] Ping Google DNS Internet (8.8.8.8)... " -NoNewline -ForegroundColor Gray
    $pingInternet = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet -ErrorAction SilentlyContinue
    if ($pingInternet) {
        Write-Host "[SUCCES - INTERNET ACTIF]" -ForegroundColor Green
    } else {
        $pingBackup = Test-Connection -ComputerName "1.1.1.1" -Count 2 -Quiet -ErrorAction SilentlyContinue
        if ($pingBackup) {
            Write-Host "[SUCCES (1.1.1.1) - INTERNET ACTIF]" -ForegroundColor Green
            $pingInternet = $true
        } else {
            Write-Host "[ECHEC - PAS D'ACCES INTERNET]" -ForegroundColor Red
        }
    }

    Write-Host " [3/3] Resolution DNS (google.com)... " -NoNewline -ForegroundColor Gray
    $dnsOk = $false
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses("google.com")
        if ($resolved -and $resolved.Count -gt 0) {
            Write-Host "[SUCCES - DNS GOOGLE FONCTIONNEL]" -ForegroundColor Green
            $dnsOk = $true
        } else {
            Write-Host "[ECHEC]" -ForegroundColor Red
        }
    } catch {
        Write-Host "[ECHEC - RESOLUTION IMPOSSIBLE]" -ForegroundColor Red
    }

    Show-Separator

    if ($pingInternet) {
        Write-Host " >>> RESULTAT: LA CONNEXION EST PLEINEMENT FONCTIONNELLE ! <<<" -ForegroundColor Green
        return $true
    } elseif ($gwOk) {
        Write-Host " [!] Passerelle joignable mais pas d'Internet direct." -ForegroundColor Yellow
        Write-Host "     - Si le portail captif est actif, connectez-vous avec :" -ForegroundColor White
        Write-Host "       Campus.fsjeso@ump.ac.ma / Fsjeso2026" -ForegroundColor Cyan
        return $false
    } else {
        Write-Host " [X] ECHEC: L'adresse IP ne fonctionne pas (Passerelle injoignable)." -ForegroundColor Red
        Write-Host "     - Conflit d'IP (deja allouee) ou routeur sature." -ForegroundColor Yellow
        return $false
    }
}

# ------------------------------------------------------------------------------
# 9. TEST PREALABLE DU MODE DHCP
# ------------------------------------------------------------------------------
function Test-DHCPAutoMode([string]$adapterName) {
    Write-Host ""
    Write-Host " ================= ETAPE 1 : TEST DU SERVEUR DHCP =================" -ForegroundColor Cyan
    Write-Host " [*] Basculement temporaire en DHCP pour verifier si le serveur repond..." -ForegroundColor DarkGray
    
    $null = Start-Process -FilePath "netsh.exe" -ArgumentList @("interface", "ipv4", "set", "address", "name=$adapterName", "source=dhcp") -Wait -PassThru -NoNewWindow
    $null = Start-Process -FilePath "netsh.exe" -ArgumentList @("interface", "ipv4", "set", "dnsservers", "name=$adapterName", "source=dhcp") -Wait -PassThru -NoNewWindow
    
    Write-Host " [*] Demande de bail IP (ipconfig /renew)..." -NoNewline -ForegroundColor DarkGray
    $null = Start-Process -FilePath "ipconfig.exe" -ArgumentList @("/renew", $adapterName) -Wait -PassThru -NoNewWindow
    Write-Host " [Fait]" -ForegroundColor DarkGray

    Start-Sleep -Seconds 4

    $netIP = Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($netIP -and $netIP.IPAddress -notlike "169.254.*" -and $netIP.IPAddress -ne "0.0.0.0") {
        Write-Host " [*] IP attribuee par DHCP : $($netIP.IPAddress)" -ForegroundColor Yellow
        $dhcpInternet = Test-ConnectionWithProgress -gateway $null -waitSeconds 3
        if ($dhcpInternet) {
            Write-Host " >>> [SUCCES] Le serveur DHCP fonctionne et Internet est accessible ! <<<" -ForegroundColor Green
            return $true
        }
    }

    Write-Host " [!] Le serveur DHCP est sature (aucun bail valide ou APIPA 169.254.x.x)." -ForegroundColor Yellow
    Write-Host " [*] Passage automatique en mode IP STATIQUE dans la plage..." -ForegroundColor Cyan
    return $false
}

# ------------------------------------------------------------------------------
# 10. RECHERCHE AUTONOME D'UNE IP VALABLE (TRAVERSAL & OVERWRITE AUTOMATIQUE)
# ------------------------------------------------------------------------------
function Invoke-AutoIpRangeHunter($profile, [string]$adapterName, [int]$maxAttempts = 10) {
    Write-Host ""
    Write-Host " ================= SCAN & TROUBLESHOOTING AUTOMATIQUE =================" -ForegroundColor Cyan
    Write-Host " Profil actif : $($profile.name)" -ForegroundColor Yellow
    Write-Host " Passerelle   : $($profile.gateway)" -ForegroundColor Gray
    Write-Host " Masque       : $($profile.subnet_mask)" -ForegroundColor Gray
    Write-Host " DNS applique : $DnsPrimary / $DnsSecondary (Google)" -ForegroundColor Green
    Write-Host " Le script va tester et ecraser les parametres successivement" -ForegroundColor White
    Write-Host " jusqu'a etablir une connexion Internet valide." -ForegroundColor White
    Show-Separator

    $testedIPs = @()
    $found = $false

    for ($i = 1; $i -le $maxAttempts; $i++) {
        # Trouver une IP candidate non encore testee
        $candIP = ""
        $genAttempts = 0
        do {
            $candIP = Get-RandomIPForProfile $profile
            $genAttempts++
        } while ($testedIPs -contains $candIP -and $genAttempts -lt 50)
        $testedIPs += $candIP

        Write-Host ""
        Write-Host " [Tentative $i/$maxAttempts] Ecrasement des parametres avec l'IP : " -NoNewline -ForegroundColor White
        Write-Host "$candIP" -ForegroundColor Yellow

        $applied = Apply-StaticConfiguration -adapterName $adapterName `
                                            -ip $candIP `
                                            -mask $profile.subnet_mask `
                                            -gateway $profile.gateway `
                                            -primaryDns $DnsPrimary `
                                            -secondaryDns $DnsSecondary `
                                            -fallbackDns $DnsFallback

        # Temps de stabilisation etendu (6s) avec negociation ARP
        $ok = Test-ConnectionWithProgress -gateway $profile.gateway -waitSeconds 6

        if ($ok) {
            Write-Host ""
            Write-Host " ==================================================================" -ForegroundColor Green
            Write-Host " >>> SUCCES TOTAL : CONNEXION ETABLIE AVEC L'IP $candIP <<<" -ForegroundColor Green
            Write-Host " ==================================================================" -ForegroundColor Green
            Write-Host "   * Adresse IP   : $candIP" -ForegroundColor White
            Write-Host "   * Passerelle   : $($profile.gateway)" -ForegroundColor White
            Write-Host "   * DNS Actif    : $DnsPrimary (Google) & $DnsSecondary" -ForegroundColor White
            Write-Host "   * Statut       : Internet est 100% operationnel !" -ForegroundColor Green
            Write-Host ""
            $found = $true
            Pause
            return $true
        } else {
            Write-Host "   [Echec] Pas de reponse sur 8.8.8.8 avec $candIP (IP bloquee/conflit)." -ForegroundColor Red
            Write-Host "   -> Auto-troubleshoot : ecrasement immediat avec l'IP suivante..." -ForegroundColor DarkGray
        }
    }

    if (-not $found) {
        Write-Host ""
        Write-Host " [!] Limite de $maxAttempts adresses testees atteinte." -ForegroundColor Yellow
        Write-Host " Voulez-vous relancer une serie de 10 tests ? (O/N) [O]" -ForegroundColor Cyan
        $c = Read-Host
        if ($c -ne "N" -and $c -ne "n") {
            return (Invoke-AutoIpRangeHunter -profile $profile -adapterName $adapterName -maxAttempts $maxAttempts)
        }
    }
    return $false
}

# ------------------------------------------------------------------------------
# 11. WORKFLOW COMPLET DE LOCALISATION (AVEC CHOIX AUTO OU MANUEL)
# ------------------------------------------------------------------------------
function Invoke-LocationWorkflow($profile, [string]$adapterName) {
    $gateway = $profile.gateway
    $mask = $profile.subnet_mask
    $calc = Get-SubnetCalculation -gateway $gateway -subnetMask $mask

    Show-Banner
    Write-Host " [ Localisation Selectionnee : $($profile.name) ]" -ForegroundColor Yellow
    Write-Host "  * Passerelle      : $gateway" -ForegroundColor Gray
    Write-Host "  * Masque de reseau: $mask (/$(if ($profile.cidr) { $profile.cidr } else { '24' }))" -ForegroundColor Gray
    if ($calc) {
        Write-Host "  * Plage autorisee : $($calc.MinHost)  -->  $($calc.MaxHost)" -ForegroundColor DarkGray
    }
    Write-Host "  * Description     : $($profile.description)" -ForegroundColor DarkGray
    Show-Separator
    Write-Host ""
    Write-Host " Comment souhaitez-vous proceder ?" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] MODE AUTOMATIQUE TOTAL (Recommande) :" -ForegroundColor Green
    Write-Host "      1. Teste le DHCP en premier." -ForegroundColor White
    Write-Host "      2. Si DHCP sature, scanne et ecrase automatiquement les IP" -ForegroundColor White
    Write-Host "         de la plage jusqu'a obtenir une connexion active." -ForegroundColor White
    Write-Host ""
    Write-Host "  [2] MODE MANUEL AVEC TEMPS DE STABILISATION ETENDU :" -ForegroundColor Yellow
    Write-Host "      1. Propose une IP ou vous permet de saisir celle de votre choix." -ForegroundColor White
    Write-Host "      2. Laisse 7 secondes pour la negociation ARP et link Wi-Fi." -ForegroundColor White
    Write-Host "      3. En cas d'echec, bascule automatiquement vers l'auto-troubleshoot." -ForegroundColor White
    Write-Host ""
    Show-Separator

    $modeChoice = Read-Host " Votre choix [1]"
    if ([string]::IsNullOrWhiteSpace($modeChoice)) { $modeChoice = "1" }

    if ($modeChoice -eq "1") {
        # 1. Test du DHCP en premier
        $dhcpOk = Test-DHCPAutoMode -adapterName $adapterName
        if ($dhcpOk) {
            Pause
            return
        }

        # 2. DHCP ayant echoue, traverser la plage automatiquement
        $null = Invoke-AutoIpRangeHunter -profile $profile -adapterName $adapterName -maxAttempts 10
        return
    }

    # MODE MANUEL
    $continueManual = $true
    while ($continueManual) {
        Show-Banner
        Write-Host " [ Configuration Manuelle - $($profile.name) ]" -ForegroundColor Yellow
        Write-Host " Plage active conseillee : $($profile.description)" -ForegroundColor DarkGray
        Show-Separator

        $suggestedIP = Find-FreeCandidateIP -profile $profile -maxAttempts 5

        Write-Host ""
        Write-Host " Adresse IP suggeree : " -NoNewline -ForegroundColor White
        Write-Host "$suggestedIP" -ForegroundColor Green
        Write-Host " Appuyez sur [ENTREE] pour accepter, ou tapez votre IP personnalisee :" -ForegroundColor Cyan
        $userIP = Read-Host " > IP voulue [$suggestedIP]"

        if ([string]::IsNullOrWhiteSpace($userIP)) {
            $userIP = $suggestedIP
        }
        $userIP = $userIP.Trim()

        if (-not (Test-IPIsInSubnet -candidateIP $userIP -gateway $gateway -subnetMask $mask)) {
            Write-Host ""
            Write-Host " [ERREUR] L'adresse '$userIP' n'appartient pas au sous-reseau ($gateway / $mask)." -ForegroundColor Red
            Start-Sleep -Seconds 2
            continue
        }

        # Verification de disponibilite prealable
        Write-Host ""
        Write-Host " [*] Verification de disponibilite de '$userIP'..." -ForegroundColor DarkGray
        $inUse = Test-Connection -ComputerName $userIP -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($inUse) {
            Write-Host " [ATTENTION] L'adresse '$userIP' repond deja sur le reseau (IP deja allouee) !" -ForegroundColor Red
            $retryGen = Read-Host " Voulez-vous en generer une autre ? (O/N) [O]"
            if ($retryGen -ne "N" -and $retryGen -ne "n") {
                continue
            }
        }

        # Application de la configuration
        $applied = Apply-StaticConfiguration -adapterName $adapterName `
                                            -ip $userIP `
                                            -mask $mask `
                                            -gateway $gateway `
                                            -primaryDns $DnsPrimary `
                                            -secondaryDns $DnsSecondary `
                                            -fallbackDns $DnsFallback

        # Temps de stabilisation etendu (7 secondes)
        $connOk = Test-ConnectionWithProgress -gateway $gateway -waitSeconds 7

        if ($connOk) {
            Write-Host ""
            Write-Host " ==================================================================" -ForegroundColor Green
            Write-Host " >>> SUCCES : VOUS ETES CONNECTE AVEC L'IP $userIP <<<" -ForegroundColor Green
            Write-Host " ==================================================================" -ForegroundColor Green
            Pause
            $continueManual = $false
        } else {
            Write-Host ""
            Write-Host " [ECHEC] L'IP $userIP ne repond pas apres stabilisation." -ForegroundColor Red
            Write-Host ""
            Write-Host " Que souhaitez-vous faire ?" -ForegroundColor Cyan
            Write-Host "  [1] AUTO-TROUBLESHOOT : Scanner et ecraser les IP automatiquement (Recommande)" -ForegroundColor Green
            Write-Host "  [2] Saisir une autre adresse manuellement" -ForegroundColor Yellow
            Write-Host "  [3] Reessayer le test avec plus de temps (10 secondes)" -ForegroundColor White
            Write-Host "  [4] Revenir en mode DHCP" -ForegroundColor Magenta
            Write-Host "  [0] Retourner au menu principal" -ForegroundColor Gray
            Write-Host ""
            $retryPick = Read-Host " Votre choix [1]"

            if ([string]::IsNullOrWhiteSpace($retryPick) -or $retryPick -eq "1") {
                $null = Invoke-AutoIpRangeHunter -profile $profile -adapterName $adapterName -maxAttempts 10
                $continueManual = $false
            } elseif ($retryPick -eq "2") {
                continue
            } elseif ($retryPick -eq "3") {
                Write-Host " [*] Attente prolongee de 10 secondes..." -ForegroundColor DarkGray
                $ok2 = Test-ConnectionWithProgress -gateway $gateway -waitSeconds 10
                if ($ok2) {
                    Write-Host " [OK] La connexion s'est retablie avec succes !" -ForegroundColor Green
                    Pause
                    $continueManual = $false
                } else {
                    Write-Host " Toujours aucun acces Internet. Lancement du troubleshoot automatique..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    $null = Invoke-AutoIpRangeHunter -profile $profile -adapterName $adapterName -maxAttempts 10
                    $continueManual = $false
                }
            } elseif ($retryPick -eq "4") {
                Apply-DHCPConfiguration -adapterName $adapterName
                Test-ConnectionDiagnostic -gateway $null
                Pause
                $continueManual = $false
            } else {
                $continueManual = $false
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 12. CONFIGURATION MANUELLE / PERSONNALISEE
# ------------------------------------------------------------------------------
function Invoke-CustomConfiguration([string]$adapterName) {
    Show-Banner
    Write-Host " [ CONFIGURATION RESEAU MANUELLE / PERSONNALISEE ]" -ForegroundColor Cyan
    Write-Host " Entrez les parametres de votre choix :" -ForegroundColor Gray
    Show-Separator

    $customIP = ""
    while (-not (Test-IsValidIPv4 $customIP)) {
        $customIP = (Read-Host " Adresse IP (ex: 100.121.195.241)").Trim()
        if (-not (Test-IsValidIPv4 $customIP)) {
            Write-Host " [!] Format IPv4 invalide. Reessayez." -ForegroundColor Red
        }
    }

    $customMask = ""
    while (-not (Test-IsValidIPv4 $customMask)) {
        $customMask = (Read-Host " Masque de sous-reseau [255.255.0.0]").Trim()
        if ([string]::IsNullOrWhiteSpace($customMask)) { $customMask = "255.255.0.0" }
        if (-not (Test-IsValidIPv4 $customMask)) {
            Write-Host " [!] Format de masque invalide. Reessayez." -ForegroundColor Red
        }
    }

    $customGW = ""
    while (-not (Test-IsValidIPv4 $customGW)) {
        $customGW = (Read-Host " Passerelle par defaut (Gateway)").Trim()
        if (-not (Test-IsValidIPv4 $customGW)) {
            Write-Host " [!] Format de passerelle invalide. Reessayez." -ForegroundColor Red
        }
    }

    $customDNS1 = (Read-Host " Serveur DNS Primaire [$DnsPrimary]").Trim()
    if ([string]::IsNullOrWhiteSpace($customDNS1)) { $customDNS1 = $DnsPrimary }

    $customDNS2 = (Read-Host " Serveur DNS Secondaire [$DnsSecondary]").Trim()
    if ([string]::IsNullOrWhiteSpace($customDNS2)) { $customDNS2 = $DnsSecondary }

    if (-not (Test-IPIsInSubnet -candidateIP $customIP -gateway $customGW -subnetMask $customMask)) {
        Write-Host ""
        Write-Host " [ATTENTION] L'adresse IP '$customIP' ne semble pas appartenir au sous-reseau de la passerelle '$customGW' avec le masque '$customMask' !" -ForegroundColor Yellow
        $force = Read-Host " Voulez-vous tout de meme appliquer cette configuration ? (O/N) [N]"
        if ($force -ne "O" -and $force -ne "o") {
            return
        }
    }

    Apply-StaticConfiguration -adapterName $adapterName `
                              -ip $customIP `
                              -mask $customMask `
                              -gateway $customGW `
                              -primaryDns $customDNS1 `
                              -secondaryDns $customDNS2 `
                              -fallbackDns $DnsFallback

    # Temps de stabilisation etendu (7 secondes)
    $ok = Test-ConnectionWithProgress -gateway $customGW -waitSeconds 7
    if ($ok) {
        Write-Host ""
        Write-Host " >>> SUCCES : CONNEXION ACTIVE ! <<<" -ForegroundColor Green
    } else {
        Test-ConnectionDiagnostic -gateway $customGW
    }
    Pause
}

# ------------------------------------------------------------------------------
# 13. AFFICHAGE DES IDENTIFIANTS DU CAMPUS
# ------------------------------------------------------------------------------
function Show-CampusCredentials {
    Show-Banner
    Write-Host " ================= IDENTIFIANTS OFFICIELS DU CAMPUS =================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Reseau Wi-Fi Principal : " -NoNewline -ForegroundColor White
    Write-Host "Campus Connecte" -ForegroundColor Green
    Write-Host "  Identifiant / Email    : " -NoNewline -ForegroundColor White
    Write-Host "Campus.fsjeso@ump.ac.ma" -ForegroundColor Yellow
    Write-Host "  Mot de passe           : " -NoNewline -ForegroundColor White
    Write-Host "Fsjeso2026 " -NoNewline -ForegroundColor Yellow
    Write-Host "(Attention : la lettre 'F' est MAJUSCULE)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Note officielle UMP : 'Avis aux etudiants : Priere d'utiliser ces" -ForegroundColor Gray
    Write-Host "  donnees a des fins d'etude uniquement.'" -ForegroundColor Gray
    Write-Host ""
    Show-Separator
    Write-Host "  Autres reseaux de secours repertories sur le campus :" -ForegroundColor Cyan
    Write-Host "  1. SSID : " -NoNewline -ForegroundColor White
    Write-Host "TP-Link_0B5A        " -NoNewline -ForegroundColor Green
    Write-Host "| Mot de passe : " -NoNewline -ForegroundColor White
    Write-Host "20542498" -ForegroundColor Yellow
    Write-Host "  2. SSID : " -NoNewline -ForegroundColor White
    Write-Host "Adsl_inwi_8399      " -NoNewline -ForegroundColor Green
    Write-Host "| Mot de passe : " -NoNewline -ForegroundColor White
    Write-Host "D842F7028399" -ForegroundColor Yellow
    Write-Host ""
    Show-Separator
    Pause
}

# ------------------------------------------------------------------------------
# 14. SELECTION DE CARTE RESEAU ALTERNATIVE
# ------------------------------------------------------------------------------
function Select-NetworkAdapter([ref]$currentAdapter) {
    Show-Banner
    Write-Host " [ SELECTION DE L'ADAPTATEUR RESEAU ]" -ForegroundColor Cyan
    Write-Host ""
    $adapters = Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed

    for ($i = 0; $i -lt $adapters.Count; $i++) {
        $a = $adapters[$i]
        $marker = if ($a.Name -eq $currentAdapter.Value) { "--> " } else { "    " }
        Write-Host "$marker[$($i+1)] $($a.Name)" -ForegroundColor $(if ($a.Name -eq $currentAdapter.Value) { "Green" } else { "White" }) -NoNewline
        Write-Host " ($($a.InterfaceDescription)) - Status: $($a.Status)" -ForegroundColor Gray
    }

    Write-Host ""
    $choice = Read-Host " Choisissez le numero de l'adaptateur [1-$($adapters.Count)]"
    $idx = [int]$choice - 1
    if ($idx -ge 0 -and $idx -lt $adapters.Count) {
        $currentAdapter.Value = $adapters[$idx].Name
        Write-Host " [OK] Carte reseau active definie sur : $($currentAdapter.Value)" -ForegroundColor Green
        Start-Sleep -Seconds 1
    }
}

# ------------------------------------------------------------------------------
# 15. BOUCLE DU MENU PRINCIPAL
# ------------------------------------------------------------------------------
function Start-CampusWifiApp {
    Ensure-AdminPrivileges

    $activeAdapterName = Get-WifiAdapterName

    # Verification et proposition de connexion initiale si non connecte
    $wlanCheck = netsh wlan show interfaces 2>$null
    if ($wlanCheck -notmatch "Campus Connecte") {
        Connect-CampusWifiInitial -adapterName $activeAdapterName
    }

    $running = $true

    while ($running) {
        Show-Banner
        Show-CurrentAdapterStatus -adapterName $activeAdapterName
        Show-Separator

        Write-Host " CHOISISSEZ VOTRE LOCALISATION SUR LE CAMPUS :" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [1] FSO Biblio    - Bibliotheque / Zone Groupe (Faculte des Sciences)" -ForegroundColor White
        Write-Host "                      Passerelle: 100.121.0.1  | Masque: 255.255.0.0" -ForegroundColor DarkGray
        Write-Host "                      Plage IP : 100.121.192.x - 100.121.193.x  (ex: 100.121.192.241)" -ForegroundColor DarkCyan
        Write-Host "                      [!] Bibliotheque en GROUPE - IP differente de Solo" -ForegroundColor DarkYellow
        Write-Host ""
        Write-Host "   [2] FSO Solo      - Salles Individuelles / Solo (Faculte des Sciences)" -ForegroundColor White
        Write-Host "                      Passerelle: 100.121.0.1  | Masque: 255.255.0.0" -ForegroundColor DarkGray
        Write-Host "                      Plage IP : 100.121.194.x uniquement  (ex: 100.121.194.144)" -ForegroundColor DarkCyan
        Write-Host "                      [!] Salles SOLO - IP differente de la Biblio Groupe" -ForegroundColor DarkYellow
        Write-Host ""
        Write-Host "   [3] FSO Master    - Master / Amphis (Faculte des Sciences)" -ForegroundColor White
        Write-Host "                      Passerelle: 100.121.0.1  | Masque: 255.255.0.0" -ForegroundColor DarkGray
        Write-Host "                      Plage IP : 100.121.195.x - 100.121.196.x  (ex: 100.121.195.100)" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "   [4] Qanon / Limen- Faculte de Droit (Amphis / Limen)" -ForegroundColor White
        Write-Host "                      Passerelle: 100.90.144.1 | Masque: 255.255.240.0" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   [5] FSJESO       - Economie, Gestion & Administration" -ForegroundColor White
        Write-Host "                      Passerelle: 100.90.144.1 | Masque: 255.255.240.0" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   [6] ENSAO        - Ecole Nationale des Sciences Appliquees" -ForegroundColor White
        Write-Host "                      Passerelle: 100.96.160.1 | Masque: 255.255.224.0" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   [7] Personnalise - Entree manuelle d'une IP / Passerelle / Masque" -ForegroundColor Yellow
        Write-Host ""
        Show-Separator
        Write-Host " ACTIONS ET OUTILS :" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   [8] Reconnecter / Configurer le compte Wi-Fi (Defaut ou Personnel)" -ForegroundColor Cyan
        Write-Host "   [9] Tester la connexion actuelle (Ping Passerelle, DNS, 8.8.8.8)" -ForegroundColor White
        Write-Host "   [D] Revenir en mode DHCP (Automatique)" -ForegroundColor Green
        Write-Host "   [I] Voir les identifiants Wi-Fi & portail (Campus.fsjeso@ump.ac.ma)" -ForegroundColor Magenta
        Write-Host "   [W] Changer de carte reseau (Actuelle: $activeAdapterName)" -ForegroundColor Gray
        Write-Host "   [0] Quitter" -ForegroundColor Red
        Write-Host ""
        Show-Separator

        $menuChoice = Read-Host " Entrez votre choix [0-9 ou D/I/W]"

        switch ($menuChoice.ToUpper()) {
            "1" {
                $fsoProfile = $DefaultProfiles | Where-Object { $_.id -eq "fso" }
                Invoke-LocationWorkflow -profile $fsoProfile -adapterName $activeAdapterName
            }
            "2" {
                $fsoSoloProfile = $DefaultProfiles | Where-Object { $_.id -eq "fso_solo" }
                Invoke-LocationWorkflow -profile $fsoSoloProfile -adapterName $activeAdapterName
            }
            "3" {
                $fsoMasterProfile = $DefaultProfiles | Where-Object { $_.id -eq "fso_master" }
                Invoke-LocationWorkflow -profile $fsoMasterProfile -adapterName $activeAdapterName
            }
            "4" {
                $qanonProfile = $DefaultProfiles | Where-Object { $_.id -eq "qanon" }
                Invoke-LocationWorkflow -profile $qanonProfile -adapterName $activeAdapterName
            }
            "5" {
                $fsjesoProfile = $DefaultProfiles | Where-Object { $_.id -eq "fsjeso" }
                Invoke-LocationWorkflow -profile $fsjesoProfile -adapterName $activeAdapterName
            }
            "6" {
                $ensaoProfile = $DefaultProfiles | Where-Object { $_.id -eq "ensao" }
                Invoke-LocationWorkflow -profile $ensaoProfile -adapterName $activeAdapterName
            }
            "7" {
                Invoke-CustomConfiguration -adapterName $activeAdapterName
            }
            "8" {
                Connect-CampusWifiInitial -adapterName $activeAdapterName
            }
            "9" {
                Show-Banner
                $routes = Get-NetRoute -InterfaceAlias $activeAdapterName -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
                $gw = if ($routes) { $routes.NextHop } else { $null }
                Test-ConnectionDiagnostic -gateway $gw
                Pause
            }
            "D" {
                Show-Banner
                Apply-DHCPConfiguration -adapterName $activeAdapterName
                Test-ConnectionDiagnostic -gateway $null
                Pause
            }
            "I" {
                Show-CampusCredentials
            }
            "W" {
                Select-NetworkAdapter -currentAdapter ([ref]$activeAdapterName)
            }
            "0" {
                $running = $false
                Write-Host ""
                Write-Host " Merci d'avoir utilise le configurateur Campus Connecte. Bonnes etudes !" -ForegroundColor Cyan
                Write-Host ""
                Start-Sleep -Seconds 1
            }
            default {
                Write-Host " [!] Choix non reconnu. Veuillez choisir une option valide." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}

# Lancement automatique de l'application si non importee
if ($MyInvocation.InvocationName -ne '.') {
    Start-CampusWifiApp
}
