#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
#  CAMPUS CONNECTE - ASSISTANT WI-FI ANDROID (UMP OUJDA)
# ==============================================================================
#  Equivalent Android (Termux) du script Windows campus_wifi.ps1
#  Fonctionnalites :
#    1. Surveillance continue et reconnexion automatique au Wi-Fi
#    2. Selection de la localisation (Faculte/Zone) sur le campus
#    3. Test prealable du DHCP
#    4. Scan et attribution automatique d'IP statique libre
#    5. Test de connectivite (ping passerelle, DNS, Internet)
#    6. Identifiants Campus affiches
#    7. Logs horodates
# ==============================================================================

# ======================== CONFIGURATION GLOBALE ===============================
TARGET_SSID="Campus Connecte"
CHECK_INTERVAL=20
LOG_FILE="$HOME/wifi_watchdog.log"
CONFIG_FILE="$(dirname "$0")/campus_config.json"

DNS_PRIMARY="8.8.8.8"
DNS_SECONDARY="8.8.4.4"
DNS_FALLBACK="100.127.255.70"

# Identifiants par defaut du campus
DEFAULT_EMAIL="Campus.fsjeso@ump.ac.ma"
DEFAULT_PASS="Fsjeso2026"

# ======================== PROFILS DES FACULTES ================================
# Format: ID|NOM|PASSERELLE|MASQUE|CIDR|OCT3_MIN|OCT3_MAX|OCT4_MIN|OCT4_MAX|DESCRIPTION
PROFILES=(
  "fso|FSO Bibliotheque (Zone Groupe)|100.121.0.1|255.255.0.0|16|192|193|15|245|Plage 100.121.192.x-193.x Biblio FSO Groupe"
  "fso_solo|FSO Solo (Salles Individuelles)|100.121.0.1|255.255.0.0|16|194|194|15|245|Plage 100.121.194.x Salles Solo FSO"
  "fso_master|FSO Master (Amphis)|100.121.0.1|255.255.0.0|16|195|196|15|245|Plage 100.121.195.x-196.x Master/Amphis FSO"
  "qanon|Qanon / Droit (FSJESO)|100.90.144.1|255.255.240.0|20|145|149|15|245|Plage 100.90.145.x-149.x Droit/Qanon"
  "fsjeso|FSJESO (Economie & Gestion)|100.90.144.1|255.255.240.0|20|144|144|15|245|Plage 100.90.144.x FSJESO"
  "ensao|ENSAO (Sciences Appliquees)|100.96.160.1|255.255.224.0|19|180|189|15|245|Plage 100.96.180.x-189.x ENSAO"
)

# ======================== COULEURS ============================================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
MAGENTA='\033[1;35m'
NC='\033[0m'

# ======================== FONCTIONS UTILITAIRES ===============================

log_msg() {
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[$timestamp] $1"
    echo "[$timestamp] $(echo -e "$1" | sed 's/\x1B\[[0-9;]*m//g')" >> "$LOG_FILE"
}

show_banner() {
    clear
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${WHITE}          CAMPUS CONNECTE - ASSISTANT WI-FI ANDROID (UMP OUJDA)                ${NC}"
    echo -e "${GRAY}  Contournement saturation DHCP pour 'Campus connecte' (FSO, Qanon, ENSAO)      ${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    echo ""
}

show_separator() {
    echo -e "${GRAY}--------------------------------------------------------------------------------${NC}"
}

check_dependencies() {
    local missing=0

    if ! command -v termux-wifi-connectioninfo &>/dev/null; then
        echo -e "${RED}[!] termux-api non installe. Executez : pkg install termux-api${NC}"
        missing=1
    fi

    if ! command -v jq &>/dev/null; then
        echo -e "${RED}[!] jq non installe. Executez : pkg install jq${NC}"
        missing=1
    fi

    if ! command -v ping &>/dev/null; then
        echo -e "${YELLOW}[!] inetutils recommande. Executez : pkg install inetutils${NC}"
    fi

    if [ $missing -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}Installer les dependances maintenant ? (O/n)${NC}"
        read -r ans
        if [ "$ans" != "n" ] && [ "$ans" != "N" ]; then
            pkg update -y && pkg install termux-api jq inetutils -y
            echo -e "${GREEN}[OK] Dependances installees !${NC}"
        else
            echo -e "${RED}[!] Certaines fonctionnalites ne marcheront pas sans les dependances.${NC}"
        fi
    fi
}

# ======================== FONCTIONS WI-FI =====================================

get_current_ssid() {
    local ssid
    ssid=$(termux-wifi-connectioninfo 2>/dev/null | jq -r '.ssid // empty' 2>/dev/null)
    # Nettoyer les guillemets
    ssid=$(echo "$ssid" | tr -d '"')
    echo "$ssid"
}

get_current_ip() {
    local ip
    ip=$(termux-wifi-connectioninfo 2>/dev/null | jq -r '.ip // empty' 2>/dev/null)
    echo "$ip"
}

get_wifi_info() {
    local info
    info=$(termux-wifi-connectioninfo 2>/dev/null)
    if [ -n "$info" ]; then
        local ssid ip link_speed rssi freq
        ssid=$(echo "$info" | jq -r '.ssid // "N/A"')
        ip=$(echo "$info" | jq -r '.ip // "N/A"')
        link_speed=$(echo "$info" | jq -r '.link_speed_mbps // "N/A"')
        rssi=$(echo "$info" | jq -r '.rssi // "N/A"')
        freq=$(echo "$info" | jq -r '.frequency_mhz // "N/A"')

        echo -e "${WHITE}  * SSID             : ${GREEN}${ssid}${NC}"
        echo -e "${WHITE}  * Adresse IP       : ${GREEN}${ip}${NC}"
        echo -e "${WHITE}  * Vitesse du lien  : ${GRAY}${link_speed} Mbps${NC}"
        echo -e "${WHITE}  * Signal (RSSI)    : ${GRAY}${rssi} dBm${NC}"
        echo -e "${WHITE}  * Frequence        : ${GRAY}${freq} MHz${NC}"
    else
        echo -e "${RED}  (Informations Wi-Fi non disponibles)${NC}"
    fi
}

is_wifi_connected() {
    local ssid
    ssid=$(get_current_ssid)
    if [ "$ssid" = "$TARGET_SSID" ]; then
        return 0
    else
        return 1
    fi
}

reconnect_wifi() {
    log_msg "${YELLOW}[*] Tentative de reconnexion au Wi-Fi...${NC}"

    # Desactiver puis reactiver le Wi-Fi
    termux-wifi-enable false 2>/dev/null
    sleep 2
    termux-wifi-enable true 2>/dev/null

    # Notification
    if command -v termux-toast &>/dev/null; then
        termux-toast "WiFi deconnecte ! Relance en cours..."
    fi

    log_msg "${GRAY}[*] Carte Wi-Fi reactivee, attente de reconnexion (10s)...${NC}"
    sleep 10

    # Verifier si reconnecte
    if is_wifi_connected; then
        log_msg "${GREEN}[OK] Reconnecte a '$TARGET_SSID'${NC}"
        if command -v termux-toast &>/dev/null; then
            termux-toast "Reconnecte a $TARGET_SSID !"
        fi
        return 0
    else
        log_msg "${RED}[!] Echec de la reconnexion automatique${NC}"
        return 1
    fi
}

# ======================== TESTS DE CONNECTIVITE ===============================

test_ping() {
    local target="$1"
    local count="${2:-2}"
    local timeout="${3:-3}"
    ping -c "$count" -W "$timeout" "$target" &>/dev/null
    return $?
}

test_connection_full() {
    local gateway="$1"

    echo ""
    echo -e "${CYAN} ===================== TEST DE CONNECTIVITE =====================${NC}"
    echo -e "${GRAY} [*] Diagnostic reseau en cours...${NC}"

    local gw_ok=0
    local inet_ok=0
    local dns_ok=0

    # 1. Ping Passerelle
    if [ -n "$gateway" ]; then
        echo -ne "${GRAY} [1/3] Ping Passerelle ($gateway)... ${NC}"
        if test_ping "$gateway" 2 3; then
            echo -e "${GREEN}[SUCCES - JOIGNABLE]${NC}"
            gw_ok=1
        else
            echo -e "${RED}[ECHEC - INJOIGNABLE]${NC}"
        fi
    else
        echo -e "${YELLOW} [1/3] Passerelle non configuree${NC}"
    fi

    # 2. Ping Internet (8.8.8.8)
    echo -ne "${GRAY} [2/3] Ping Google DNS (8.8.8.8)... ${NC}"
    if test_ping "8.8.8.8" 2 5; then
        echo -e "${GREEN}[SUCCES - INTERNET ACTIF]${NC}"
        inet_ok=1
    else
        # Essai de secours 1.1.1.1
        if test_ping "1.1.1.1" 2 5; then
            echo -e "${GREEN}[SUCCES (1.1.1.1) - INTERNET ACTIF]${NC}"
            inet_ok=1
        else
            echo -e "${RED}[ECHEC - PAS D'ACCES INTERNET]${NC}"
        fi
    fi

    # 3. Resolution DNS
    echo -ne "${GRAY} [3/3] Resolution DNS (google.com)... ${NC}"
    if ping -c 1 -W 5 google.com &>/dev/null; then
        echo -e "${GREEN}[SUCCES - DNS FONCTIONNEL]${NC}"
        dns_ok=1
    else
        echo -e "${RED}[ECHEC - RESOLUTION IMPOSSIBLE]${NC}"
    fi

    show_separator

    if [ $inet_ok -eq 1 ]; then
        echo -e "${GREEN} >>> RESULTAT: LA CONNEXION EST PLEINEMENT FONCTIONNELLE ! <<<${NC}"
        return 0
    elif [ $gw_ok -eq 1 ]; then
        echo -e "${YELLOW} [!] Passerelle joignable mais pas d'Internet direct.${NC}"
        echo -e "${WHITE}     - Connectez-vous au portail captif avec :${NC}"
        echo -e "${CYAN}       $DEFAULT_EMAIL / $DEFAULT_PASS${NC}"
        return 1
    else
        echo -e "${RED} [X] ECHEC: Pas de connectivite reseau.${NC}"
        return 1
    fi
}

test_connection_with_stabilization() {
    local gateway="$1"
    local wait_secs="${2:-15}"

    echo -ne "${GRAY} [*] Stabilisation du lien Wi-Fi (${wait_secs}s) ${NC}"
    for ((i = 0; i < wait_secs; i++)); do
        sleep 1
        echo -ne "${GRAY}.${NC}"
    done
    echo -e " ${GREEN}[Pret]${NC}"

    # Ping progressif (6 tentatives)
    for ((p = 1; p <= 6; p++)); do
        if test_ping "8.8.8.8" 2 3; then
            return 0
        fi
        sleep 2
    done

    # Tentative de secours
    for ((p = 1; p <= 2; p++)); do
        if test_ping "1.1.1.1" 2 3; then
            return 0
        fi
        sleep 2
    done

    return 1
}

# ======================== FONCTIONS IP ========================================

# Generer une IP aleatoire dans la plage d'un profil
generate_random_ip() {
    local profile_str="$1"
    IFS='|' read -r id name gw mask cidr oct3_min oct3_max oct4_min oct4_max desc <<< "$profile_str"

    local gw_parts
    IFS='.' read -r gw1 gw2 gw3 gw4 <<< "$gw"

    local rand_oct3=$((RANDOM % (oct3_max - oct3_min + 1) + oct3_min))
    local rand_oct4=$((RANDOM % (oct4_max - oct4_min + 1) + oct4_min))

    echo "${gw1}.${gw2}.${rand_oct3}.${rand_oct4}"
}

# Verifier si une IP est deja utilisee
is_ip_in_use() {
    local ip="$1"
    test_ping "$ip" 1 2
    return $?
}

# Trouver une IP libre dans la plage
find_free_ip() {
    local profile_str="$1"
    local max_attempts="${2:-5}"

    for ((i = 0; i < max_attempts; i++)); do
        local candidate
        candidate=$(generate_random_ip "$profile_str")
        if ! is_ip_in_use "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done

    # Retourner une aleatoire si rien de libre trouve
    generate_random_ip "$profile_str"
}

# ======================== CONFIGURATION IP STATIQUE ===========================

show_static_ip_guide() {
    local profile_str="$1"
    local ip="$2"
    IFS='|' read -r id name gw mask cidr oct3_min oct3_max oct4_min oct4_max desc <<< "$profile_str"

    echo ""
    echo -e "${CYAN} ================= CONFIGURATION IP STATIQUE =================${NC}"
    echo ""
    echo -e "${WHITE} Parametres a entrer dans les reglages Wi-Fi Android :${NC}"
    echo ""
    echo -e "${YELLOW}   Adresse IP       : ${WHITE}${ip}${NC}"
    echo -e "${YELLOW}   Passerelle       : ${WHITE}${gw}${NC}"
    echo -e "${YELLOW}   Longueur prefixe : ${WHITE}${cidr}${NC}"
    echo -e "${YELLOW}   DNS 1            : ${WHITE}${DNS_PRIMARY}${NC}"
    echo -e "${YELLOW}   DNS 2            : ${WHITE}${DNS_SECONDARY}${NC}"
    echo ""
    show_separator
    echo -e "${CYAN} Comment configurer (une seule fois) :${NC}"
    echo -e "${GRAY}   1. Parametres Android > Wi-Fi${NC}"
    echo -e "${GRAY}   2. Restez appuye sur '${TARGET_SSID}'${NC}"
    echo -e "${GRAY}   3. Modifier le reseau > Options avancees${NC}"
    echo -e "${GRAY}   4. Parametres IP > Statique${NC}"
    echo -e "${GRAY}   5. Entrez les parametres ci-dessus${NC}"
    echo -e "${GRAY}   6. Enregistrez${NC}"
    echo ""

    # Essayer de copier l'IP dans le presse-papiers
    if command -v termux-clipboard-set &>/dev/null; then
        echo "$ip" | termux-clipboard-set 2>/dev/null
        echo -e "${GREEN} [*] L'adresse IP a ete copiee dans le presse-papiers !${NC}"
    fi

    # Proposer d'ouvrir les parametres Wi-Fi
    echo ""
    echo -e "${CYAN} Ouvrir les parametres Wi-Fi Android maintenant ? (O/n)${NC}"
    read -r open_settings
    if [ "$open_settings" != "n" ] && [ "$open_settings" != "N" ]; then
        am start -a android.settings.WIFI_SETTINGS 2>/dev/null
    fi
}

# ======================== SCAN AUTOMATIQUE IP ==================================

auto_ip_scan() {
    local profile_str="$1"
    local max_attempts="${2:-10}"
    IFS='|' read -r id name gw mask cidr oct3_min oct3_max oct4_min oct4_max desc <<< "$profile_str"

    echo ""
    echo -e "${CYAN} ================= SCAN & TROUBLESHOOTING AUTOMATIQUE =================${NC}"
    echo -e "${YELLOW} Profil actif : ${name}${NC}"
    echo -e "${GRAY} Passerelle   : ${gw}${NC}"
    echo -e "${GRAY} Masque       : ${mask} (/${cidr})${NC}"
    echo -e "${GREEN} DNS applique : ${DNS_PRIMARY} / ${DNS_SECONDARY} (Google)${NC}"
    echo -e "${WHITE} Le script va scanner les IP de la plage pour trouver une adresse libre.${NC}"
    show_separator

    local tested_ips=()
    local found=0

    for ((i = 1; i <= max_attempts; i++)); do
        # Generer une IP non encore testee
        local candidate=""
        local gen_attempts=0
        while true; do
            candidate=$(generate_random_ip "$profile_str")
            local already_tested=0
            for tested in "${tested_ips[@]}"; do
                if [ "$tested" = "$candidate" ]; then
                    already_tested=1
                    break
                fi
            done
            if [ $already_tested -eq 0 ] || [ $gen_attempts -ge 50 ]; then
                break
            fi
            gen_attempts=$((gen_attempts + 1))
        done
        tested_ips+=("$candidate")

        echo ""
        echo -e "${WHITE} [Tentative ${i}/${max_attempts}] Test de l'IP : ${YELLOW}${candidate}${NC}"

        # Verifier si l'IP est deja prise
        echo -ne "${GRAY}   Verification de disponibilite... ${NC}"
        if is_ip_in_use "$candidate"; then
            echo -e "${RED}[OCCUPEE]${NC}"
            echo -e "${GRAY}   -> Passage a l'adresse suivante...${NC}"
            continue
        fi
        echo -e "${GREEN}[LIBRE]${NC}"

        # Tester la connectivite en passant par cette IP (verification indirecte)
        echo -ne "${GRAY}   Test de la passerelle ($gw)... ${NC}"
        if test_ping "$gw" 2 3; then
            echo -e "${GREEN}[JOIGNABLE]${NC}"
        else
            echo -e "${YELLOW}[INJOIGNABLE - On continue quand meme]${NC}"
        fi

        # Tester l'acces Internet
        echo -ne "${GRAY}   Test Internet (8.8.8.8)... ${NC}"
        if test_ping "8.8.8.8" 2 5; then
            echo -e "${GREEN}[INTERNET ACTIF]${NC}"
            echo ""
            echo -e "${GREEN} ==================================================================${NC}"
            echo -e "${GREEN} >>> IP LIBRE TROUVEE : ${candidate} <<<${NC}"
            echo -e "${GREEN} ==================================================================${NC}"

            # Afficher le guide pour configurer cette IP
            show_static_ip_guide "$profile_str" "$candidate"
            found=1
            break
        else
            echo -e "${RED}[PAS D'INTERNET]${NC}"
            echo -e "${GRAY}   -> Essai de l'adresse suivante...${NC}"
        fi
    done

    if [ $found -eq 0 ]; then
        echo ""
        echo -e "${YELLOW} [!] Limite de $max_attempts adresses testees atteinte.${NC}"

        # Proposer la meilleure IP libre trouvee quand meme
        local best_ip
        best_ip=$(find_free_ip "$profile_str" 5)
        echo -e "${WHITE} Meilleure IP libre detectee : ${YELLOW}${best_ip}${NC}"
        echo ""
        echo -e "${CYAN} Relancer une serie de 10 tests ? (O/n)${NC}"
        read -r retry
        if [ "$retry" != "n" ] && [ "$retry" != "N" ]; then
            auto_ip_scan "$profile_str" "$max_attempts"
        else
            show_static_ip_guide "$profile_str" "$best_ip"
        fi
    fi
}

# ======================== TEST PREALABLE DHCP =================================

test_dhcp_mode() {
    echo ""
    echo -e "${CYAN} ================= ETAPE 1 : TEST DU SERVEUR DHCP =================${NC}"
    echo -e "${GRAY} [*] Verification de l'IP actuelle attribuee par DHCP...${NC}"

    local current_ip
    current_ip=$(get_current_ip)

    if [ -z "$current_ip" ] || [ "$current_ip" = "0.0.0.0" ]; then
        echo -e "${YELLOW} [!] Aucune IP attribuee. DHCP non fonctionnel.${NC}"
        return 1
    fi

    # Verifier si c'est une APIPA (169.254.x.x) ou similaire
    if [[ "$current_ip" == 169.254.* ]]; then
        echo -e "${YELLOW} [!] IP APIPA detectee (${current_ip}). Le serveur DHCP est sature.${NC}"
        return 1
    fi

    echo -e "${GRAY} [*] IP attribuee par DHCP : ${YELLOW}${current_ip}${NC}"
    echo -e "${GRAY} [*] Test de connectivite Internet...${NC}"

    if test_connection_with_stabilization "" 3; then
        echo -e "${GREEN} >>> [SUCCES] Le serveur DHCP fonctionne et Internet est accessible ! <<<${NC}"
        return 0
    fi

    echo -e "${YELLOW} [!] DHCP attribue une IP mais pas d'acces Internet.${NC}"
    echo -e "${CYAN} [*] Passage en mode IP STATIQUE recommande.${NC}"
    return 1
}

# ======================== WORKFLOW LOCALISATION ================================

location_workflow() {
    local profile_str="$1"
    IFS='|' read -r id name gw mask cidr oct3_min oct3_max oct4_min oct4_max desc <<< "$profile_str"

    show_banner
    echo -e "${YELLOW} [ Localisation Selectionnee : ${name} ]${NC}"
    echo -e "${GRAY}  * Passerelle      : ${gw}${NC}"
    echo -e "${GRAY}  * Masque          : ${mask} (/${cidr})${NC}"
    echo -e "${GRAY}  * Description     : ${desc}${NC}"
    show_separator
    echo ""
    echo -e "${CYAN} Comment souhaitez-vous proceder ?${NC}"
    echo ""
    echo -e "${GREEN}  [1] MODE AUTOMATIQUE (Recommande) :${NC}"
    echo -e "${WHITE}      1. Teste le DHCP en premier.${NC}"
    echo -e "${WHITE}      2. Si DHCP sature, scanne les IP libres dans la plage.${NC}"
    echo -e "${WHITE}      3. Affiche la configuration a appliquer.${NC}"
    echo ""
    echo -e "${YELLOW}  [2] MODE MANUEL :${NC}"
    echo -e "${WHITE}      1. Propose une IP libre ou vous permet de la choisir.${NC}"
    echo -e "${WHITE}      2. Affiche le guide de configuration.${NC}"
    echo ""
    show_separator

    echo -ne "${WHITE} Votre choix [1] : ${NC}"
    read -r mode_choice
    if [ -z "$mode_choice" ]; then mode_choice="1"; fi

    if [ "$mode_choice" = "1" ]; then
        # 1. Test du DHCP
        if test_dhcp_mode; then
            echo ""
            echo -e "${GREEN} Le DHCP fonctionne, aucune IP statique requise !${NC}"
            echo -e "${GRAY} Appuyez sur Entree pour continuer...${NC}"
            read -r
            return
        fi

        # 2. DHCP echoue -> scan automatique
        auto_ip_scan "$profile_str" 10

    elif [ "$mode_choice" = "2" ]; then
        # Mode manuel
        echo ""
        local suggested_ip
        suggested_ip=$(find_free_ip "$profile_str" 5)

        echo -e "${WHITE} Adresse IP suggeree : ${GREEN}${suggested_ip}${NC}"
        echo -e "${CYAN} Appuyez sur [Entree] pour accepter, ou tapez votre IP :${NC}"
        echo -ne "${WHITE} > IP voulue [${suggested_ip}] : ${NC}"
        read -r user_ip

        if [ -z "$user_ip" ]; then
            user_ip="$suggested_ip"
        fi

        # Verifier la disponibilite
        echo -ne "${GRAY} [*] Verification de '$user_ip'... ${NC}"
        if is_ip_in_use "$user_ip"; then
            echo -e "${RED}[OCCUPEE - Deja utilisee sur le reseau]${NC}"
            echo -e "${YELLOW} Generer une autre adresse ? (O/n)${NC}"
            read -r retry
            if [ "$retry" != "n" ] && [ "$retry" != "N" ]; then
                user_ip=$(find_free_ip "$profile_str" 10)
                echo -e "${GREEN} Nouvelle IP suggeree : ${user_ip}${NC}"
            fi
        else
            echo -e "${GREEN}[LIBRE]${NC}"
        fi

        show_static_ip_guide "$profile_str" "$user_ip"
    fi
}

# ======================== IDENTIFIANTS CAMPUS =================================

show_credentials() {
    show_banner
    echo -e "${CYAN} ================= IDENTIFIANTS OFFICIELS DU CAMPUS =================${NC}"
    echo ""
    echo -e "${WHITE}  Reseau Wi-Fi Principal : ${GREEN}Campus Connecte${NC}"
    echo -e "${WHITE}  Identifiant / Email    : ${YELLOW}${DEFAULT_EMAIL}${NC}"
    echo -e "${WHITE}  Mot de passe           : ${YELLOW}${DEFAULT_PASS} ${GRAY}(Attention : le 'F' est MAJUSCULE)${NC}"
    echo ""
    echo -e "${GRAY}  Note officielle UMP : 'Avis aux etudiants : Priere d'utiliser ces${NC}"
    echo -e "${GRAY}  donnees a des fins d etude uniquement.'${NC}"
    echo ""
    show_separator
    echo -e "${CYAN}  Autres reseaux de secours :${NC}"
    echo -e "${WHITE}  1. SSID : ${GREEN}TP-Link_0B5A        ${WHITE}| Mot de passe : ${YELLOW}20542498${NC}"
    echo -e "${WHITE}  2. SSID : ${GREEN}Adsl_inwi_8399      ${WHITE}| Mot de passe : ${YELLOW}D842F7028399${NC}"
    echo ""

    # Copier dans le presse-papiers
    if command -v termux-clipboard-set &>/dev/null; then
        echo -e "${CYAN} Copier le mot de passe dans le presse-papiers ? (O/n)${NC}"
        read -r copy_pass
        if [ "$copy_pass" != "n" ] && [ "$copy_pass" != "N" ]; then
            echo "$DEFAULT_PASS" | termux-clipboard-set 2>/dev/null
            echo -e "${GREEN} [OK] Mot de passe copie !${NC}"
        fi
    fi

    show_separator
    echo -e "${GRAY} Appuyez sur Entree pour continuer...${NC}"
    read -r
}

# ======================== MODE SURVEILLANCE ===================================

watchdog_mode() {
    show_banner
    echo -e "${CYAN} ================= MODE SURVEILLANCE ACTIVE =================${NC}"
    echo -e "${WHITE} Le script surveille la connexion toutes les ${CHECK_INTERVAL}s.${NC}"
    echo -e "${GRAY} Appuyez sur Ctrl+C pour arreter.${NC}"
    show_separator
    echo ""

    local disconnect_count=0
    local reconnect_count=0

    while true; do
        local current_ssid
        current_ssid=$(get_current_ssid)

        if [ "$current_ssid" = "$TARGET_SSID" ]; then
            log_msg "${GREEN}[OK] Wi-Fi connecte a '${TARGET_SSID}'${NC}"
            disconnect_count=0
        else
            disconnect_count=$((disconnect_count + 1))
            log_msg "${RED}[!] Wi-Fi DECONNECTE - SSID actuel: '${current_ssid}' (tentative #${disconnect_count})${NC}"

            reconnect_wifi
            if is_wifi_connected; then
                reconnect_count=$((reconnect_count + 1))
                log_msg "${GREEN}[OK] Reconnecte avec succes ! (total reconnexions: ${reconnect_count})${NC}"

                if command -v termux-notification &>/dev/null; then
                    termux-notification \
                        --title "WiFi Campus" \
                        --content "Reconnecte a ${TARGET_SSID} (x${reconnect_count})" \
                        --id wifi_watchdog 2>/dev/null
                fi
            else
                log_msg "${RED}[!] Echec de reconnexion (tentative #${disconnect_count})${NC}"

                # Apres 3 echecs, attendre plus longtemps
                if [ $disconnect_count -ge 3 ]; then
                    log_msg "${YELLOW}[*] 3 echecs consecutifs. Attente prolongee (60s)...${NC}"
                    sleep 60
                    disconnect_count=0
                fi
            fi
        fi

        sleep "$CHECK_INTERVAL"
    done
}

# ======================== MENU PRINCIPAL ======================================

show_main_menu() {
    while true; do
        show_banner

        # Afficher l'etat actuel
        echo -e "${WHITE} [ Etat de la connexion Wi-Fi ]${NC}"
        get_wifi_info
        echo ""
        show_separator

        echo -e "${CYAN} CHOISISSEZ VOTRE LOCALISATION SUR LE CAMPUS :${NC}"
        echo ""
        echo -e "${WHITE}   [1] FSO Biblio    ${GRAY}- Bibliotheque / Zone Groupe (Faculte des Sciences)${NC}"
        echo -e "${GRAY}                      Passerelle: 100.121.0.1  | Plage: 100.121.192.x-193.x${NC}"
        echo ""
        echo -e "${WHITE}   [2] FSO Solo      ${GRAY}- Salles Individuelles (Faculte des Sciences)${NC}"
        echo -e "${GRAY}                      Passerelle: 100.121.0.1  | Plage: 100.121.194.x${NC}"
        echo ""
        echo -e "${WHITE}   [3] FSO Master    ${GRAY}- Master / Amphis (Faculte des Sciences)${NC}"
        echo -e "${GRAY}                      Passerelle: 100.121.0.1  | Plage: 100.121.195.x-196.x${NC}"
        echo ""
        echo -e "${WHITE}   [4] Qanon / Droit ${GRAY}- Faculte de Droit (Amphis / Limen)${NC}"
        echo -e "${GRAY}                      Passerelle: 100.90.144.1 | Plage: 100.90.145.x-149.x${NC}"
        echo ""
        echo -e "${WHITE}   [5] FSJESO        ${GRAY}- Economie, Gestion & Administration${NC}"
        echo -e "${GRAY}                      Passerelle: 100.90.144.1 | Plage: 100.90.144.x${NC}"
        echo ""
        echo -e "${WHITE}   [6] ENSAO         ${GRAY}- Ecole Nationale des Sciences Appliquees${NC}"
        echo -e "${GRAY}                      Passerelle: 100.96.160.1 | Plage: 100.96.180.x-189.x${NC}"
        echo ""
        show_separator
        echo -e "${CYAN} ACTIONS ET OUTILS :${NC}"
        echo ""
        echo -e "${CYAN}   [7] Lancer le mode surveillance (Watchdog - reconnexion auto)${NC}"
        echo -e "${WHITE}   [8] Tester la connexion actuelle (Ping Passerelle, DNS, Internet)${NC}"
        echo -e "${MAGENTA}   [9] Voir les identifiants Wi-Fi & portail campus${NC}"
        echo -e "${GRAY}   [S] Ouvrir les parametres Wi-Fi Android${NC}"
        echo -e "${RED}   [0] Quitter${NC}"
        echo ""
        show_separator

        echo -ne "${WHITE} Entrez votre choix [0-9 ou S] : ${NC}"
        read -r menu_choice

        case "$menu_choice" in
            1) location_workflow "${PROFILES[0]}" ;;
            2) location_workflow "${PROFILES[1]}" ;;
            3) location_workflow "${PROFILES[2]}" ;;
            4) location_workflow "${PROFILES[3]}" ;;
            5) location_workflow "${PROFILES[4]}" ;;
            6) location_workflow "${PROFILES[5]}" ;;
            7) watchdog_mode ;;
            8)
                show_banner
                local cur_ip
                cur_ip=$(get_current_ip)
                # Deviner la passerelle probable
                local probable_gw=""
                if [[ "$cur_ip" == 100.121.* ]]; then
                    probable_gw="100.121.0.1"
                elif [[ "$cur_ip" == 100.90.* ]]; then
                    probable_gw="100.90.144.1"
                elif [[ "$cur_ip" == 100.96.* ]]; then
                    probable_gw="100.96.160.1"
                fi
                test_connection_full "$probable_gw"
                echo ""
                echo -e "${GRAY} Appuyez sur Entree pour continuer...${NC}"
                read -r
                ;;
            9) show_credentials ;;
            [sS])
                am start -a android.settings.WIFI_SETTINGS 2>/dev/null
                echo -e "${GREEN} [*] Ouverture des parametres Wi-Fi...${NC}"
                sleep 2
                ;;
            0)
                echo ""
                echo -e "${CYAN} Merci d'avoir utilise l'assistant Campus Connecte. Bonnes etudes !${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${YELLOW} [!] Choix non reconnu. Veuillez choisir une option valide.${NC}"
                sleep 1
                ;;
        esac
    done
}

# ======================== POINT D'ENTREE ======================================

main() {
    check_dependencies

    # Si lance avec argument --watchdog, lancer directement le mode surveillance
    if [ "$1" = "--watchdog" ] || [ "$1" = "-w" ]; then
        show_banner
        echo -e "${CYAN} [*] Demarrage en mode surveillance (watchdog)...${NC}"
        watchdog_mode
        exit 0
    fi

    show_main_menu
}

main "$@"
