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

La commande télécharge et exécute l'installateur de ce dépôt. Les fichiers de l'application
sont téléchargés depuis une même révision GitHub avant installation. Le dépôt doit être public.

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

Tapez simplement :

```sh
campuse
```

L'installation détecte Bash/Zsh et ajoute un alias à leur configuration. Le programme
est copié dans `~/.local/share/campuse` et le lanceur dans `~/.local/bin/campuse`.
Pour un autre shell, ou si l'alias n'est pas encore chargé, utilisez directement :

```sh
~/.local/bin/campuse
```

### 6. Première connexion et réparation

1. Choisissez l'interface Wi-Fi si plusieurs cartes sont présentes.
2. Une connexion déjà fonctionnelle est conservée. Si l'accès Internet reste incertain,
   le script propose de conserver la connexion par défaut.
3. S'il manque un profil Campus, acceptez l'installation initiale et entrez votre email
   institutionnel et votre mot de passe dans l'utilitaire fourni.
4. Aux lancements suivants, choisissez le compte enregistré, identifié par son email masqué,
   ou demandez explicitement son remplacement.
5. L'assistant tente DHCP et les DNS automatiques, même avec une adresse APIPA (`169.254.x.x`).
6. Si la configuration IP échoue après authentification, choisissez votre zone. L'assistant
   vérifie les conflits d'adresse puis essaie des IP statiques dans la plage correspondante.
7. Gardez le terminal ouvert pendant la session réparée. À l'invite de fin, appuyez sur
   **Entrée**, ou utilisez **Ctrl+C**, pour restaurer DHCP/DNS et supprimer le profil temporaire.

L'activation ou le renouvellement DHCP est limité à 15 secondes ; les vérifications et
les demandes d'identifiants peuvent ajouter du temps. Les changements d'IP peuvent
interrompre temporairement le réseau. `sudo arping` peut demander votre mot de passe Linux
pour vérifier les conflits ; ne lancez pas tout l'assistant avec sudo.

**Authentification et DHCP sont deux étapes différentes :** un mauvais compte ou un
certificat refusé empêche l'accès au réseau. Une IP statique ne résout pas ce problème.
En revanche, si l'authentification réussit mais que DHCP ne fournit pas d'adresse utilisable,
la recherche d'IP statique peut aider.

Les identifiants sont gérés par NetworkManager, pas par un fichier de mots de passe propre
à l'assistant. Le [guide Linux](linux/README.md) précise les limites de stockage et décrit
la copie corrigée de l'utilitaire fourni.

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
| `campuse: command not found` | Ouvrez un nouveau terminal ou lancez `~/.local/bin/campuse`. |
| `No module named dbus` ou `distro` | Installez `python3-dbus` et `python3-distro` avec les paquets indiqués plus haut. |
| `nmcli` ou `arping` introuvable | Installez respectivement `network-manager` ou `iputils-arping`. |
| Aucune interface Wi-Fi sous Kali/WSL | WSL ne fournit pas directement la carte Wi-Fi de Windows ; utilisez un environnement Linux avec une carte Wi-Fi accessible. |
| Compte/certificat refusé | Vérifiez l'identifiant institutionnel, le mot de passe et le profil fourni ; ne forcez pas une IP statique. |

## État de validation

L'installation Linux via `sh`, les alias Bash/Zsh et les scénarios de connexion ont été
vérifiés sous Kali avec des opérations réseau simulées. La connexion 802.1X, les
permissions et le DHCP réels restent à valider sur un ordinateur Linux au campus.
