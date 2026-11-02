# 📱 Guide Wi-Fi Campus Connecte pour Android

Ce dossier contient les outils et méthodes pour maintenir la connexion Wi-Fi **Campus Connecte** sur Android et gérer l'IP Statique.

---

## 🚀 Méthode 1 : Script Termux (`wifi_watchdog.sh`)

### Prérequis
1. Installez **Termux** et l'application compagnon **Termux:API** (disponibles sur [F-Droid](https://f-droid.org/en/packages/com.termux/)).
2. Ouvrez Termux et installez les dépendances :
   ```bash
   pkg update && pkg install termux-api jq -y
   ```

### Lancement du script
1. Copiez ou créez le script `wifi_watchdog.sh` dans Termux.
2. Donnez les droits d'exécution et lancez-le :
   ```bash
   chmod +x wifi_watchdog.sh
   ./wifi_watchdog.sh
   ```

Le script vérifie toutes les 20 secondes si le smartphone est bien connecté à `Campus Connecte`. Si la connexion est rompue, il réinitialise le Wi-Fi pour forcer la reconnexion automatique.

---

## 🛠️ Méthode 2 : Sans script (Via MacroDroid)

Si vous préférez une interface graphique sans terminal :
1. Installez l'application gratuite **MacroDroid**.
2. **Déclencheur (Trigger)** : *Connectivité > Wi-Fi SSID connecté/déconnecté > Déconnecté de "Campus Connecte"*.
3. **Actions** :
   - *Conditions/Boucles > Attendre 5 secondes*.
   - *Connectivité > Activer le Wi-Fi*.
   - *Connectivité > Se connecter au réseau Wi-Fi > "Campus Connecte"*.

---

## 🌐 Configuration de l'IP Statique sur Android

Sur Android (sans root), l'IP statique se configure une seule fois dans le système :
1. Allez dans **Paramètres > Réseau et Internet > Wi-Fi**.
2. Restez appuyé sur **Campus Connecte** puis choisissez **Modifier le réseau** (ou l'icône ⚙️).
3. Ouvrez **Options avancées** > **Paramètres IP**.
4. Changez `DHCP` en `Statique`.
5. Renseignez :
   - **Adresse IP** : Ex. `100.121.195.241` (ou selon la plage de votre zone FSO/Faculté).
   - **Passerelle** : `100.121.0.1`
   - **Longueur du préfixe** : `16` (ou Masque `255.255.0.0`)
   - **DNS 1** : `8.8.8.8`
   - **DNS 2** : `8.8.4.4`
6. Enregistrez. Android réutilisera automatiquement ces paramètres à chaque reconnexion.
