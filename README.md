# Campus Connecte

Assistant Wi-Fi pour le réseau **Campus Connecte** de l'Université Mohammed Premier
à Oujda. Deux versions sont disponibles : [Windows](windows/) et [Linux](linux/).

L'assistant conserve une connexion déjà fonctionnelle. Si une réparation est nécessaire,
il essaie DHCP avant de proposer une IP statique adaptée à votre zone du campus.

## Installation Windows

### 1. Vérifier les prérequis

- Windows 10 ou Windows 11, avec une carte Wi-Fi activée.
- Une connexion Internet pour télécharger les fichiers.
- La possibilité d'accepter la demande administrateur au lancement de l'assistant.
- Aucun Python ni logiciel supplémentaire à installer.

L'installation se fait avec votre compte Windows habituel. Elle crée un raccourci sur
le Bureau, sans démarrer l'assistant ni modifier les paramètres Wi-Fi.

### 2. Installer en une commande

Ouvrez le menu **Démarrer**, recherchez **Windows PowerShell**, puis ouvrez-le normalement
(pas besoin de choisir « Exécuter en tant qu'administrateur » pour l'installation).
Copiez cette ligne, collez-la dans PowerShell et appuyez sur **Entrée** :

```powershell
irm https://raw.githubusercontent.com/neo848/Campusump/main/windows/bootstrap.ps1 | iex
```

Attendez le message **Installation terminée !**. Le raccourci **Campus Connecte** apparaît
sur votre Bureau, y compris si celui-ci est synchronisé avec OneDrive.

La commande télécharge et exécute l'installateur de ce dépôt

### 3. Autre méthode : télécharger le ZIP

Si vous préférez ne pas utiliser de commande :

1. Sur [la page du dépôt](https://github.com/neo848/Campusump), cliquez sur **Code → Download ZIP**.
2. Faites un clic droit sur le ZIP téléchargé, puis **Extraire tout**.
3. Ouvrez le dossier extrait, puis le sous-dossier **windows**.
4. Double-cliquez sur **INSTALLER.bat** et attendez la confirmation.

Ne lancez pas l'installateur directement depuis l'archive : tous les fichiers du dossier
`windows` doivent être extraits ensemble. Le dossier téléchargé peut être supprimé après installation.

### 4. Lancer et utiliser l'assistant

1. Double-cliquez sur **Campus Connecte** sur le Bureau.
2. Acceptez la demande administrateur Windows : elle est nécessaire pour changer IP et DNS.
3. Si la connexion fonctionne déjà, l'assistant la conserve.
4. Sinon, choisissez le compte par défaut ou **[2] Mon propre compte**. Le compte personnel
   est enregistré avec le chiffrement Windows ; un email masqué permet de le reconnaître
   et de choisir de le réutiliser ou de le remplacer.
5. Choisissez votre zone. Avant les essais statiques, l'assistant tente DHCP et les DNS automatiques.
6. Gardez l'assistant ouvert pendant l'utilisation de la connexion réparée.
7. Pour quitter, tapez **0**, puis **Entrée**, ou utilisez **Ctrl+C**. Les interfaces dont
   l'IP/DNS ont été modifiés pendant la session sont remises en automatique.

La restauration peut interrompre temporairement la connexion. Fermer de force le processus
ou couper l'alimentation ne garantit pas ce nettoyage.

Les fichiers installés se trouvent dans `%LOCALAPPDATA%\Programs\CampusConnecte`.
Le compte personnel chiffré se trouve dans `%LOCALAPPDATA%\CampusConnecte` et reste lié
au compte Windows et à l'ordinateur utilisés. Utilisez le même compte lors de l'élévation.

Sans installation, vous pouvez aussi lancer `windows/Lancer_Campus_Wifi.bat`, en gardant
les fichiers du dossier ensemble.

## Installation Linux — Kali, Ubuntu, Debian, Mint

Le parcours prévu est : **installer les dépendances → installer l'assistant → lancer
`campuse` au campus → choisir le compte si nécessaire → laisser essayer DHCP → choisir
une zone seulement si le programme le propose → garder la session ouverte → quitter
en laissant la restauration se terminer**.

L'installation prépare les fichiers et la commande. La connexion et les éventuelles
modifications réseau commencent lorsque vous lancez l'assistant.

### 1. Vérifier l'environnement

Il faut **Python 3.9 ou supérieur**, une carte Wi-Fi utilisable et **NetworkManager**.
Le lanceur fonctionne avec `sh` ; la commande `campuse` est configurée pour **Bash et Zsh**.

Cette version vise un ordinateur Linux équipé du Wi-Fi. Sous **WSL**, l'interface réseau
virtuelle ne remplace pas la carte Wi-Fi de Windows : WSL permet de vérifier le code,
mais ne valide pas une connexion Wi-Fi réelle au campus.

### 2. Installer les dépendances

Ouvrez un terminal et exécutez ces commandes sur Kali, Ubuntu, Debian ou Mint :

```sh
sudo apt update
sudo apt install python3 python3-dbus python3-distro network-manager iproute2 iputils-arping wget
```

Entrez votre mot de passe Linux si demandé ; il est normal qu'aucun caractère ne s'affiche.
Ces commandes installent des paquets système. Si vous utilisez déjà un autre gestionnaire
réseau, ne changez pas sa configuration pendant une connexion que vous devez conserver.

Vérifiez ensuite les prérequis, sans modifier le réseau :

```sh
python3 --version
nmcli general status
nmcli device status
```

NetworkManager doit être actif et une interface de type **wifi** doit apparaître.
Si `nmcli` est introuvable ou que NetworkManager n'est pas actif, corrigez ce prérequis
avant de lancer l'assistant. Le script ne prend pas en charge un système utilisant
uniquement `systemd-networkd` ou `iwd` sans NetworkManager.

### 3. Installer en une commande

Dans le terminal, avec votre utilisateur habituel et **sans sudo** :

```sh
wget -qO- https://raw.githubusercontent.com/neo848/Campusump/main/linux/bootstrap.sh | bash
```

Attendez **Installation terminée**, puis fermez et rouvrez le terminal.
Cette commande télécharge et exécute l'installateur du dépôt public. Elle ne modifie pas
le Wi-Fi, ne lance pas l'assistant et n'installe pas les dépendances système.

### 4. Autre méthode : télécharger le ZIP

1. Sur GitHub, cliquez sur **Code → Download ZIP**.
2. Extrayez l'archive avec votre gestionnaire de fichiers.
3. Ouvrez un terminal dans le sous-dossier **linux** du dossier extrait.
4. Exécutez, sans sudo :

```sh
sh INSTALLER.sh
```

`sh` est bien la commande prévue ; `bash INSTALLER.sh` fonctionne également.
Aucun `chmod` n'est nécessaire pour cette méthode. Ouvrez ensuite un nouveau terminal.

### 5. Lancer depuis n'importe quel dossier

Au campus, activez le Wi-Fi et placez-vous à portée du réseau **Campus Connecte**.
Ouvrez un terminal avec votre utilisateur habituel, puis tapez **`campuse` avec un `e`
à la fin**, sans `sudo` :

```sh
campuse
```

L'installation détecte Bash/Zsh et ajoute un alias à leur configuration. Le programme
est copié dans `~/.local/share/campuse` et le lanceur dans `~/.local/bin/campuse`.
Pour un autre shell, ou si l'alias n'est pas encore chargé, utilisez directement :

```sh
~/.local/bin/campuse
```

Gardez les fichiers du sous-dossier `linux` ensemble si vous souhaitez lancer directement
la copie du dépôt, sans installer de commande. Depuis la racine du dépôt :

```sh
python3 linux/campuse.py
```

Cette commande utilise les fichiers du dépôt ; `campuse` utilise la copie installée
dans votre dossier personnel. Après une mise à jour des sources, relancez l'installateur
pour actualiser cette copie. Utilisez une seule session à la fois.

### 6. Choisir l'interface et le compte

Si plusieurs cartes Wi-Fi sont disponibles, saisissez le numéro de celle à utiliser,
puis **Entrée**. Avec une seule carte, la sélection est automatique.

Le programme vérifie d'abord la connexion sur cette interface :

- **`Connexion operationnelle : aucun changement.`** : le test réseau a réussi.
  Le programme se termine normalement ; aucun compte ni aucune zone n'est à choisir.
- **`IP valide, Internet non confirme. Conserver ? [O/n]`** : une adresse IP existe,
  mais le test n'a pas confirmé l'accès. **Entrée** conserve la connexion ; **`n`**
  autorise la suite des essais. Un filtrage ou un portail peut expliquer ce résultat.
- Sans adresse utilisable, le programme poursuit vers la sélection du compte.

Si aucun profil Campus n'existe, l'assistant propose sa configuration. Répondez **`o`**
à la confirmation, puis suivez l'utilitaire fourni pour saisir votre email institutionnel
et votre mot de passe. L'utilitaire peut ouvrir des boîtes de dialogue. Une fois le profil
créé, l'assistant recherche les comptes disponibles.

Exemple de menu avec un seul compte enregistré :

```text
1. a***@ump.ac.ma
2. Configurer/remplacer le compte
Compte Campus (0 = annuler) :
```

Saisissez **`1`**, puis **Entrée**, pour utiliser ce compte. Les numéros varient s'il y a
plusieurs profils : choisissez celui affiché devant votre compte. **`0`** annule ; une
lettre ou un numéro absent du menu provoque une nouvelle demande.

Pour changer de compte, choisissez **Configurer/remplacer le compte** et confirmez avec
**`o`**. Cette opération remplace les anciens profils Campus. Après ce remplacement
depuis le menu, relancez `campuse` pour utiliser le nouveau compte. Si le programme
demande de quitter un autre profil actif pour passer au Campus, **`o`** accepte et
**Entrée** annule le changement.

### 7. Laisser la connexion se faire

L'assistant crée une copie temporaire du profil choisi et tente une adresse IP et des
DNS automatiques, même si l'adresse précédente était de type `169.254.x.x` (APIPA).

| Étape | Comportement attendu |
| --- | --- |
| Activation Wi-Fi et DHCP | Jusqu'à **90 secondes** pour l'association, l'authentification et la configuration IP ; le délai propre au DHCP est de **30 secondes**. Répondez aux éventuelles demandes d'identifiants. |
| DHCP réussi, ou connexion incertaine que vous choisissez de conserver | L'invite `Connexion conservee. Gardez ce terminal ouvert...` apparaît. L'assistant attend ; vous pouvez utiliser la connexion. |
| Configuration IP atteinte mais connexion inutilisable | L'assistant propose votre zone sur le campus. Choisissez le numéro correspondant à votre emplacement réel. |
| Recherche d'IP statique | Il vérifie les conflits avec `arping`, puis essaie au maximum **10 adresses candidates** de la zone. Une adresse occupée est écartée. |
| Connexion rétablie après un essai statique | Le message `Connexion retablie...` apparaît. Laissez le terminal ouvert pendant l'utilisation. |
| Authentification ou activation bloquée avant la configuration IP | L'assistant affiche l'erreur et engage le nettoyage ; il ne force pas une IP statique. |

Les 90 secondes concernent une activation, pas la durée totale du programme : les
vérifications, les saisies et les essais successifs peuvent prolonger la session.
`sudo arping` peut demander le mot de passe de votre utilisateur Linux pour vérifier
les conflits d'adresse. Ce mot de passe est distinct de celui du compte Campus.
Si la vérification ARP échoue, l'adresse candidate n'est pas appliquée.

**Authentification et DHCP sont deux étapes différentes :** un mauvais compte ou un
certificat refusé empêche l'accès au réseau. Une IP statique ne résout pas ce problème.
Le choix d'une zone apparaît seulement lorsque le programme dispose d'indices d'un
problème de configuration IP après l'authentification.

### 8. Garder la session ouverte, puis quitter

Après une réparation, y compris une réussite DHCP, gardez le terminal ouvert. L'attente
à l'invite de fin est normale : appuyer sur **Entrée** à cet endroit signifie **terminer
la session**, et non confirmer la connexion pour continuer à l'utiliser.

Pour quitter, appuyez sur **Entrée** à l'invite de fin ou utilisez **Ctrl+C**. Si la session
a modifié la connexion et qu'aucun autre profil n'a été activé entre-temps, l'assistant
tente de réactiver le profil d'origine avec DHCP et DNS automatiques. Il tente ensuite
de supprimer sa copie temporaire. Un autre réseau choisi entre-temps reste intact.

Attendez la fin du message `Retour IP DHCP et DNS automatiques...` : la réactivation
peut prendre jusqu'à **90 secondes** et interrompre temporairement l'accès. La connexion
réparée par IP statique peut donc être perdue en quittant si DHCP ne fonctionne toujours
pas. Une erreur de restauration est affichée séparément, sans masquer l'erreur initiale.
Une fermeture forcée ou une coupure de courant ne garantit pas le nettoyage.

Les identifiants sont gérés par NetworkManager, pas par un fichier de mots de passe propre
à l'assistant. Le [guide Linux](linux/README.md) précise les limites de stockage et décrit
la copie corrigée de l'utilitaire fourni.

### 9. En cas de délai dépassé

Un message `Timeout expired` signifie que l'opération n'a pas abouti dans le délai prévu.
Il ne prouve pas à lui seul que le mot de passe est faux ou que DHCP est en panne.
Attendez la fin du nettoyage, puis relevez l'état réseau et les journaux récents :

```sh
nmcli -f GENERAL.STATE,GENERAL.REASON,IP4.ADDRESS,IP4.GATEWAY device show
sudo journalctl -u NetworkManager --since "10 minutes ago" --no-pager -n 150
```

Masquez l'email, les identifiants et les informations personnelles avant de partager les
résultats. Si l'affichage annonce encore **15 secondes maximum pour l'activation**,
la copie lancée utilise l'ancien délai : réinstallez depuis la version corrigée des sources.

## Mettre à jour

Quittez d'abord l'assistant. Relancez ensuite la commande d'installation correspondant
à votre système, ou téléchargez le nouveau ZIP et relancez son installateur.

- **Windows** : le compte personnel chiffré et la configuration locale sont conservés.
- **Linux** : les fichiers de l'assistant sont actualisés sans doubler l'alias ; les profils
  NetworkManager ne sont pas remplacés par cette installation.

## Dépannage rapide

| Problème | Que vérifier ? |
| --- | --- |
| Téléchargement 404 | Le dépôt doit être public et l'adresse copiée en entier. |
| Erreur de guillemets avec `irm ... \| iex` | Utilisez la commande actuelle : le caractère invisible qui causait cette erreur a été retiré de l'installateur Windows. |
| `campus: command not found` | La commande s'écrit `campuse`, avec un `e` à la fin. |
| `campuse: command not found` | Ouvrez un nouveau terminal ou lancez `~/.local/bin/campuse`. |
| `No module named dbus` ou `distro` | Installez `python3-dbus` et `python3-distro` avec les paquets indiqués plus haut. |
| `nmcli` ou `arping` introuvable | Installez respectivement `network-manager` ou `iputils-arping`. |
| Aucune interface Wi-Fi sous Kali/WSL | WSL ne fournit pas directement la carte Wi-Fi de Windows ; utilisez un environnement Linux avec une carte Wi-Fi accessible. |
| Compte/certificat refusé | Vérifiez l'identifiant institutionnel, le mot de passe et le profil fourni ; ne forcez pas une IP statique. |
| `Connexion operationnelle : aucun changement.` puis retour au terminal | C'est le résultat attendu lorsqu'une connexion fonctionne déjà. |
| Attente après `Connexion conservee...` ou `Connexion retablie...` | La session est maintenue ouverte volontairement. Entrée ou Ctrl+C la termine. |
| `Timeout expired` ou `nettoyage incomplet` | Attendez la fin de la restauration et consultez l'état et les journaux NetworkManager ci-dessus. |

## État de validation

L'installation Linux via `sh`, les alias Bash/Zsh et les scénarios de connexion ont été
vérifiés sous Kali avec des opérations réseau simulées. La connexion 802.1X, les
permissions et le DHCP réels restent à valider sur un ordinateur Linux au campus.
