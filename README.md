# 🎓 Assistant Réseau Wi-Fi - Campus Connecté (UMP Oujda)

> Scripts d'automatisation, watchdog de reconnexion et gestion des IP statiques pour **Windows 10 et 11**, conçus pour contourner la saturation du serveur DHCP du réseau **Campus connecte** à l'Université Mohammed Premier d'Oujda.

## Installation simple sur Windows

1. Telechargez [Campus-Connecte-Windows.zip](https://github.com/neo848/Campusump/raw/refs/heads/main/dist/Campus-Connecte-Windows.zip), puis faites **Extraire tout**.
2. Dans le dossier extrait, double-cliquez sur **INSTALLER.bat**.
3. Ensuite, lancez **Campus Connecte** depuis le raccourci sur le Bureau.
   Acceptez la demande administrateur au lancement de l'assistant.

L'installation ne modifie pas la connexion et ne lance pas l'assistant.
Les fichiers sont copies dans `%LOCALAPPDATA%\Programs\CampusConnecte` ; le raccourci
utilise le Bureau Windows de l'utilisateur, y compris un Bureau redirige vers OneDrive.
Le dossier extrait peut ensuite etre supprime. Pour mettre a jour, quittez l'assistant
et relancez le nouvel installateur : le compte chiffre et la configuration locale restent conserves.
Depuis le depot, le meme fichier **INSTALLER.bat** fonctionne directement.

Pour generer le ZIP : `powershell.exe -NoProfile -ExecutionPolicy Bypass -File windows/Build_Package.ps1`.
Le resultat se trouve dans `dist/Campus-Connecte-Windows.zip`.
Test de l'installation sans lancer l'assistant :
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/installer_regression.ps1`.

---

## 📁 Structure du Projet

```text
campus/
├── windows/                    # Outils et scripts pour Windows
│   ├── personal_account.ps1    # Stockage chiffre du compte personnel
│   ├── campus_wifi.ps1         # Script principal (Auto-troubleshoot, IP statique, scan)
│   ├── wifi_watchdog.ps1       # Script de surveillance et reconnexion automatique
│   ├── Lancer_Campus_Wifi.bat  # Lanceur avec élévation administrateur (UAC)
│   ├── campus_config.json      # Configuration des plages IP et facultés
│   ├── Wi-Fi-Campus Connecte.xml # Profil XML 802.1X
│   └── campus.txt
│
└── README.md                   # Documentation générale du projet
```

---

## 📌 1. Nouveautés & Mode Pilote Automatique (Auto-Troubleshoot)

1. **Temps de Stabilisation Étendu (25 secondes) & Négociation ARP :**
   - L'affectation manuelle d'une IP nécessite un délai pour que Windows, l'antenne Wi-Fi et le routeur de l'amphi négocient les paquets ARP.
   - Le script accorde désormais **25 secondes de stabilisation** avec un compte à rebours visuel, suivi d'un ping progressif multi-tentatives (6 essais × 2 pings avec 2s d'intervalle).
   - Vidage automatique du cache ARP (`netsh delete arpcache`) et DNS (`ipconfig /flushdns`) à chaque changement d'IP.

2. **Test Préalable du DHCP en Premier :**
   - Avant de basculer en IP statique, le script vérifie si le serveur DHCP a de la place disponible et répond.
   - S'il fonctionne, vous êtes connecté immédiatement.
   - Si le DHCP est saturé (APIPA `169.254.x.x` ou absence de réponse), il **nettoie l'adresse APIPA résiduelle**, **reset la carte réseau** (Disable/Enable + reconnexion Wi-Fi), puis bascule automatiquement en mode IP statique.

3. **Auto-Troubleshooting par Écrasement Successif des Paramètres :**
   - Le script **ne s'arrête plus sur une simple erreur d'IP non joignable**.
   - Il traverse et scanne automatiquement la plage d'IP de la faculté (FSO, Qanon, FSJESO, ENSAO).
   - Il **écrase successivement les paramètres réseau** de la carte avec une nouvelle IP candidate libre, attend la négociation et teste `8.8.8.8` jusqu'à obtenir un accès Internet 100% fonctionnel !

4. **Connexion Wi-Fi Initiale & Compte UMP :**
   - Importation automatique du profil `Campus Connecte`.
   - Choix du compte :
     - **Compte par défaut :** `Campus.fsjeso@ump.ac.ma` / `Fsjeso2026` *(F majuscule)*.
     - **Compte personnel :** Saisie de votre email et mot de passe institutionnel UMP.
   - Configuration EAP-TTLS 802.1X directe dans Windows.

5. **DNS Google Forcé (Toujours) :**
   - Pendant la configuration Campus, le DNS est `8.8.8.8` / `8.8.4.4`, même en mode DHCP.
   - Secours UMP : `100.127.255.70`

---

## 🗺️ 2. Cartographie Réseau UMP

### ❓ Vos coordonnées réseau :
```text
IPv4 Address. . . . . . . . . . . : 100.121.195.241
Subnet Mask . . . . . . . . . . . : 255.255.0.0
Default Gateway . . . . . . . . . : 100.121.0.1 (et 10.16.33.122)
```
👉 **Ces coordonnées appartiennent à la zone FSO Master (Faculté des Sciences - Master / Amphis) !**

| # | Localisation / Faculté | Passerelle (Gateway) | Masque | Plages IP Observées & Actives |
| :---: | :--- | :--- | :---: | :--- |
| **[1]** | **FSO Bibliothèque** *(Zone Groupe)* | `100.121.0.1` | `255.255.0.0` | `100.121.192.10` à `100.121.193.250` *(ex: 100.121.192.241)* |
| **[2]** | **FSO Solo** *(Salles Individuelles)* ⚠️ | `100.121.0.1` | `255.255.0.0` | `100.121.194.10` à `100.121.194.250` *(ex: 100.121.194.144)* |
| **[3]** | **FSO Master** *(Master / Amphis)* | `100.121.0.1` | `255.255.0.0` | `100.121.195.10` à `100.121.196.250` *(ex: 100.121.195.100)* |
| **[4]** | **Qanon / Droit** *(Amphis / Limen)* | `100.90.144.1` | `255.255.240.0` | `100.90.145.10` à `100.90.149.250` *(ex: 100.90.147.210)* |
| **[5]** | **FSJESO (Économie & Gestion)** | `100.90.144.1` | `255.255.240.0` | `100.90.144.10` à `100.90.144.250` *(ex: 100.90.144.37)* |
| **[6]** | **ENSAO (Sciences Appliquées)** | `100.96.160.1` | `255.255.224.0` | `100.96.180.10` à `100.96.189.250` *(ex: 100.96.187.21)* |

> ⚠️ **Important — FSO Biblio ≠ FSO Solo :** Bien que FSO Biblio et FSO Solo partagent la même passerelle (`100.121.0.1`) et le même masque, leurs **plages IP sont différentes**. La bibliothèque (zone groupe) utilise `100.121.192.x–193.x`, tandis que les salles Solo utilisent `100.121.194.x`. Choisissez le bon profil selon votre emplacement physique, sinon l'IP assignée ne fonctionnera pas.

---

## 🚀 3. Comment Utiliser le Script sur N'importe Quel PC

### 📋 Prérequis
- **Windows 10 ou 11** (toute édition)
- **Carte Wi-Fi** fonctionnelle
- Être à portée du réseau Wi-Fi **"Campus Connecte"** de l'UMP
- **Aucun logiciel supplémentaire** n'est nécessaire (tout est intégré dans Windows)

### 📥 Étape 1 : Récupérer les fichiers

Copiez ces **4 fichiers** sur le PC (clé USB, téléchargement, etc.) :

```
📁 campus/
├── 📄 Lancer_Campus_Wifi.bat        ← Le lanceur (double-cliquer dessus)
├── 📄 personal_account.ps1         ← Stockage du compte personnel
├── 📄 campus_wifi.ps1               ← Le script principal
└── 📄 Wi-Fi-Campus Connecte.xml     ← Le profil Wi-Fi (importé automatiquement)
```

> Le fichier `campus_config.json` est **optionnel** (le script a des valeurs par défaut intégrées).

### ▶️ Étape 2 : Lancer le script

1. **Double-cliquez** sur **`Lancer_Campus_Wifi.bat`**
2. **Acceptez la fenêtre UAC** (droits administrateur requis pour modifier la carte réseau)
3. C'est tout ! Le script démarre automatiquement.

> **💡 Pourquoi un fichier `.bat` ?**
> Windows bloque par défaut l'exécution des scripts PowerShell (`.ps1`). Le fichier `Lancer_Campus_Wifi.bat` contourne cette restriction automatiquement avec `-ExecutionPolicy Bypass` et demande les droits administrateur via UAC. **Vous n'avez pas besoin de modifier quoi que ce soit dans les paramètres de Windows.**

### 🎮 Étape 3 : Utilisation

1. **Choisissez votre faculté** (ex: `1` pour FSO Biblio, `2` pour FSO Solo, `3` pour FSO Master).
2. **Choisissez le `[1] Mode Automatique Total`** (recommandé) :
   - Le script teste d'abord le DHCP.
   - Si saturé, il nettoie l'adresse APIPA, reset la carte, puis scanne et écrase automatiquement les IP de la plage jusqu'à trouver une IP active qui répond au ping `8.8.8.8` !
3. Pour **revenir en mode automatique** à la maison, choisissez l'option **`[D] Revenir en mode DHCP`**.

### ❓ FAQ

**Q: Est-ce que je dois installer quelque chose ?**
> Non, rien du tout. Le script utilise uniquement des commandes Windows natives (`netsh`, `ipconfig`, PowerShell).

**Q: Est-ce que ça marche sur n'importe quel PC Windows ?**
> Oui, Windows 10 et 11. Il faut juste que le PC ait une carte Wi-Fi et être sur le campus UMP.

**Q: J'ai copié que le `.ps1`, ça marche ?**
> Vous pouvez, mais il faudra lancer PowerShell en Administrateur et taper manuellement :
> ```powershell
> Set-ExecutionPolicy Bypass -Scope Process -Force
> .\campus_wifi.ps1
> ```
> C'est plus simple d'utiliser le `.bat` qui fait tout ça automatiquement.

**Q: Le script modifie-t-il des paramètres permanents ?**
> Le script change l'IP et le DNS de la carte Wi-Fi. Pour tout remettre comme avant, utilisez l'option **`[D] Revenir en mode DHCP`** dans le menu.

## Compte personnel et sortie (Windows)

Gardez `windows/personal_account.ps1` a cote de `campus_wifi.ps1` lors de la copie des fichiers.
Le choix **[2] Mon propre compte** demande le mot de passe avec une saisie masquee.
L'email et le mot de passe sont chiffres ensemble par Windows DPAPI dans
`%LOCALAPPDATA%\CampusConnecte\personal-account.dpapi`, avec des permissions limitees
au compte Windows courant. Le fichier n'est pas portable vers un autre compte Windows
ou ordinateur. Utilisez toujours le meme compte Windows lors de l'elevation UAC.

Au lancement, l'email apparait sous la forme `a***@ump.ac.ma`. Dans le mode personnel,
choisissez **Reutiliser**, **Remplacer** (nouvel email et mot de passe), ou **Annuler**.
Le remplacement est atomique ; le compte par defaut [1] ne remplace jamais votre compte
personnel. Aucun mot de passe personnel n'est copie dans le presse-papiers.
Windows conserve aussi les identifiants 802.1X configures dans son profil Wi-Fi.

**[0] Quitter** ou **Ctrl+C** remet les interfaces selectionnees pendant la session en IPv4 DHCP et
DNS automatiques. **[D]** applique immediatement cette meme restauration. Les DNS Google
ne restent forces que pendant les operations de connexion du script. La restauration
est egalement tentee si une erreur interrompt l'application. Elle peut interrompre
la connexion actuelle : quittez lorsque vous avez termine de l'utiliser.

Utilisez le menu [0] ou Ctrl+C pour quitter proprement. Le nettoyage utilise une execution PowerShell independante de celle interrompue et protege la restauration contre un second Ctrl+C. Fermer brutalement la fenetre, tuer le
processus ou couper le courant ne garantit pas l'execution du nettoyage PowerShell.
Dans ce cas, utilisez [D] au prochain lancement ou remettez IP et DNS en automatique
dans les parametres Windows.

### Verification sans modifier le reseau

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/windows_regression.ps1`
verifie le chiffrement avec des comptes fictifs et simule toutes les commandes reseau.
Les fichiers de test temporaires sont supprimes a la fin.
Le test `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/ctrl_c_cleanup.ps1` interrompt reellement une execution PowerShell et verifie le nettoyage avec un adaptateur simule, sans charger de commande reseau.
