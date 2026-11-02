#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Script de surveillance et reconnexion automatique Wi-Fi pour Android (Termux)
# ==============================================================================

TARGET_SSID="Campus Connecte"
INTERVAL=20 # Intervalle de vérification en secondes

echo "=============================================="
echo "  Watchdog Wi-Fi - Campus Connecte (Android) "
echo "=============================================="
echo "[*] Surveillance active pour le SSID : '$TARGET_SSID'"
echo "[*] Intervalle de vérification : ${INTERVAL}s"
echo "----------------------------------------------"

# Vérification de l'outil termux-wifi-connectioninfo
if ! command -v termux-wifi-connectioninfo &> /dev/null; then
    echo "[!] Attention : termux-api n'est pas installé !"
    echo "[*] Exécutez : pkg install termux-api jq -y"
    exit 1
fi

while true; do
    # Récupération du SSID actuellement connecté
    CURRENT_SSID=$(termux-wifi-connectioninfo 2>/dev/null | jq -r '.ssid // empty')

    # Nettoyer les guillemets éventuels autour du SSID
    CURRENT_SSID=$(echo "$CURRENT_SSID" | tr -d '"')

    if [ "$CURRENT_SSID" != "$TARGET_SSID" ]; then
        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
        echo "[$TIMESTAMP] [!] Wi-Fi déconnecté ou SSID différent ('$CURRENT_SSID'). Tentative de relance..."

        # Relance du module Wi-Fi pour forcer la reconnexion automatique
        termux-wifi-enable false
        sleep 2
        termux-wifi-enable true

        # Notification toast facultative
        if command -v termux-toast &> /dev/null; then
            termux-toast "Wi-Fi déconnecté ! Relance en cours..."
        fi

        echo "[$TIMESTAMP] [*] Carte Wi-Fi réactivée, attente de reconnexion..."
        sleep 8
    else
        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
        echo "[$TIMESTAMP] [OK] Connecté à '$TARGET_SSID'"
    fi

    sleep $INTERVAL
done
