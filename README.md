# Campus Connecte

## Installation en une commande (depot public)

**Linux**, dans un terminal, sans sudo :

```sh
wget -qO- https://raw.githubusercontent.com/neo848/Campusump/main/linux/bootstrap.sh | bash
```

Ouvrir ensuite un nouveau terminal et taper **campuse** depuis n'importe quel dossier.
Python 3 est requis pour l'installation ; [prerequis reseau Linux](linux/README.md).

**Windows**, dans PowerShell, avec votre compte habituel :

```powershell
irm https://raw.githubusercontent.com/neo848/Campusump/main/windows/bootstrap.ps1 | iex
```

Utiliser ensuite le raccourci **Campus Connecte** sur le Bureau.

Ces commandes telechargent et executent l'installateur du depot. Elles ne lancent pas
l'assistant Wi-Fi et ne modifient pas la connexion. Tous les fichiers sont telecharges
depuis une meme revision GitHub avant installation. Le depot doit etre public ; aucune
modification de sa visibilite n'est effectuee par l'installateur.

## Installation depuis le ZIP

- **Windows** : ouvrir `windows/`, puis double-cliquer sur `INSTALLER.bat`.
- **Linux** : ouvrir `linux/`, puis executer `sh INSTALLER.sh` sans sudo.

## Connexion

Une connexion deja fonctionnelle est conservee. Sinon, les assistants essaient d'abord
DHCP et DNS automatiques, avec une attente limitee a 15 secondes pour le renouvellement
ou l'activation (les verifications et demandes d'identifiants peuvent ajouter du temps).
Meme avec une IP APIPA, DHCP est retente avant la recherche d'IP statique par zone.
Une erreur d'authentification Linux n'est pas traitee comme un echec DHCP.
Les modifications de session sont nettoyees a la sortie, y compris Ctrl+C.
