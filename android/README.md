# 📱 Campus Connecte - Assistant Wi-Fi Android (UMP Oujda)

> Équivalent Android du script Windows `campus_wifi.ps1`. Surveillance, reconnexion automatique, scan d'IP libres et configuration statique pour le réseau **Campus Connecte** de l'Université Mohammed Premier d'Oujda.

---

## 🚀 Fonctionnalités

| # | Fonctionnalité | Description |
|---|---|---|
| 1 | **Menu interactif** | Même interface que la version Windows avec choix de localisation (FSO, Qanon, ENSAO...) |
| 2 | **Test DHCP automatique** | Vérifie si le serveur DHCP répond avant de passer en statique |
| 3 | **Scan IP automatique** | Scanne et teste les IP de la plage jusqu'à trouver une adresse libre |
| 4 | **Mode Watchdog** | Surveillance continue (toutes les 20s) + reconnexion automatique |
| 5 | **Test de connectivité** | Ping passerelle, DNS Google, résolution DNS |
| 6 | **Identifiants campus** | Affiche les identifiants Wi-Fi et portail + copie presse-papiers |
| 7 | **Guide IP statique** | Instructions pas à pas pour configurer l'IP dans Android |
| 8 | **Logs horodatés** | Historique dans `~/wifi_watchdog.log` |
| 9 | **Notifications** | Toast et notifications Android via Termux:API |

---

## 📦 Prérequis

1. Installer **Termux** depuis [F-Droid](https://f-droid.org/en/packages/com.termux/) (la version Play Store est obsolète).
2. Installer **Termux:API** depuis [F-Droid](https://f-droid.org/en/packages/com.termux.api/).
3. Ouvrir Termux et exécuter :
   ```bash
   pkg update -y && pkg install termux-api jq inetutils -y
   ```

---

## ▶️ Utilisation

### Mode interactif (menu complet) :
```bash
chmod +x wifi_watchdog.sh
./wifi_watchdog.sh
```

### Mode surveillance directe (watchdog) :
```bash
./wifi_watchdog.sh --watchdog
```
ou
```bash
./wifi_watchdog.sh -w
```

---

## 🗺️ Localisations supportées

| # | Zone | Passerelle | Plage IP |
|---|---|---|---|
| 1 | FSO Bibliothèque (Groupe) | `100.121.0.1` | `100.121.192.x` - `100.121.193.x` |
| 2 | FSO Solo (Salles Individuelles) | `100.121.0.1` | `100.121.194.x` |
| 3 | FSO Master (Amphis) | `100.121.0.1` | `100.121.195.x` - `100.121.196.x` |
| 4 | Qanon / Droit | `100.90.144.1` | `100.90.145.x` - `100.90.149.x` |
| 5 | FSJESO (Économie) | `100.90.144.1` | `100.90.144.x` |
| 6 | ENSAO | `100.96.160.1` | `100.96.180.x` - `100.96.189.x` |

---

## 🌐 Configuration IP Statique Android

Le script **trouve l'IP libre** et vous guide pour la configurer :

1. **Paramètres Android** → **Wi-Fi**
2. Appui long sur **Campus Connecte** → **Modifier le réseau**
3. **Options avancées** → **Paramètres IP** → **Statique**
4. Entrez les paramètres affichés par le script
5. Enregistrez

> **Note :** L'IP statique est mémorisée par Android et réappliquée automatiquement à chaque reconnexion.

---

## ⚠️ Limitations Android (sans root)

- Le script **ne peut pas changer l'IP automatiquement** via la ligne de commande sans root
- Il **détecte, scanne et propose** l'IP optimale, puis ouvre les paramètres Wi-Fi pour vous
- Le mode Watchdog **réactive le Wi-Fi** automatiquement (ne nécessite pas root)
