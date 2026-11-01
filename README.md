# 🎓 Assistant Réseau Wi-Fi - Campus Connecté (UMP Oujda)

> Script professionnel d'automatisation complète et de gestion des adresses IP statiques pour Windows, conçu pour contourner la saturation du serveur DHCP du réseau **Campus connecte** à l'Université Mohammed Premier d'Oujda.

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
   - Le DNS est **toujours** `8.8.8.8` / `8.8.4.4`, même en mode DHCP.
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

Copiez ces **3 fichiers** sur le PC (clé USB, téléchargement, etc.) :

```
📁 campus/
├── 📄 Lancer_Campus_Wifi.bat        ← Le lanceur (double-cliquer dessus)
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
