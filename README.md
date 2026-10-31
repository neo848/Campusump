# 🎓 Assistant Réseau Wi-Fi - Campus Connecté (UMP Oujda)

> Script professionnel d'automatisation complète et de gestion des adresses IP statiques pour Windows, conçu pour contourner la saturation du serveur DHCP du réseau **Campus connecte** à l'Université Mohammed Premier d'Oujda.

---

## 📌 1. Nouveautés & Mode Pilote Automatique (Auto-Troubleshoot)

1. **Temps de Stabilisation Étendu (7 secondes) & Négociation ARP :**
   - L'affectation manuelle d'une IP nécessite un court délai pour que Windows, l'antenne Wi-Fi et le routeur de l'amphi négocient les paquets ARP.
   - Le script accorde désormais **7 secondes de stabilisation** avec un compte à rebours visuel, suivi d'un ping progressif multi-tentatives (évite les faux échecs au premier paquet).
   - Vidage automatique du cache ARP (`netsh delete arpcache`) et DNS (`ipconfig /flushdns`) à chaque changement d'IP.

2. **Test Préalable du DHCP en Premier :**
   - Avant de basculer en IP statique, le script vérifie si le serveur DHCP a de la place disponible et répond.
   - S'il fonctionne, vous êtes connecté immédiatement.
   - Si le DHCP est saturé (APIPA `169.254.x.x` ou absence de réponse), il bascule automatiquement en mode IP statique.

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

5. **DNS Google par Défaut :**
   - Primaire : `8.8.8.8`
   - Secondaire : `8.8.4.4`
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

## 🚀 3. Comment Lancer le Script

Double-cliquez simplement sur :
👉 **[`Lancer_Campus_Wifi.bat`](file:///C:/Users/win%2011/Documents/campus/Lancer_Campus_Wifi.bat)**

1. Choisissez votre faculté (ex: `1` pour FSO Biblio, `2` pour FSO Solo, `3` pour FSO Master).
2. Choisissez le **`[1] Mode Automatique Total`** :
   - Le script teste le DHCP.
   - Si saturé, il scanne et écrase automatiquement les IP de la plage jusqu'à trouver une IP active qui répond au ping `8.8.8.8` !
3. Pour revenir en automatique à la maison, choisissez l'option **`[D] Revenir en mode DHCP`**.
