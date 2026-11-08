# Campus Connecte — Linux

Cible : distributions avec Python 3.9+ et NetworkManager (Ubuntu, Mint, Debian, Kali).
Les systemes utilisant uniquement systemd-networkd ou iwd ne sont pas pris en charge.

## Installation

Sur Debian/Ubuntu/Kali, installer les dependances si elles manquent :

```sh
sudo apt install python3 python3-dbus python3-distro network-manager iproute2 iputils-arping
cd linux
sh INSTALLER.sh
```

Ne pas lancer INSTALLER.sh avec sudo. Ouvrir un nouveau terminal puis taper `campuse`,
depuis n'importe quel repertoire. Bash et Zsh sont detectes via le shell utilisateur ;
un alias est ajoute au fichier de configuration correspondant, ainsi qu'aux fichiers
Bash/Zsh deja existants. Le lanceur utilise sh et Python, independamment du shell.
Pour un autre shell : utiliser `~/.local/bin/campuse` ou ajouter `~/.local/bin` au PATH.
Relancer l'installation met a jour les fichiers sans dupliquer l'alias.

L'installation copie seulement les fichiers dans `~/.local/share/campuse` et cree le
lanceur `~/.local/bin/campuse`. Elle ne change pas le reseau et n'installe aucun paquet.

## Fonctionnement

1. Choix de l'interface si plusieurs cartes Wi-Fi sont disponibles.
2. Test TCP sur l'adresse de cette interface. Une connexion fonctionnelle reste intacte.
   Une IP valide mais non verifiee est conservee par defaut (portail/filtrage possible).
3. Reutilisation d'un profil Campus existant, avec email masque, ou installation/remplacement
   explicite du compte via l'utilitaire fourni. Ne jamais utiliser une IP statique pour
   contourner une erreur d'authentification.
4. Si APIPA ou configuration IP incomplete apres authentification, choix de la zone,
   verification ARP des conflits, puis au maximum 10 IP candidates. `sudo arping` peut
   demander le mot de passe Linux ; NetworkManager utilise ses autorisations habituelles.
5. Les essais utilisent un clone temporaire du profil, avec reconnexion possible lors du
   changement d'IP. Garder le terminal ouvert pendant la session reparee.
6. Entree/Ctrl+C restaure DHCP et DNS automatiques puis supprime le clone temporaire.
   Si l'utilisateur a change de reseau entre-temps, ce nouveau reseau reste intact.

Aucun mot de passe n'est stocke par l'assistant. NetworkManager gere les identifiants :
le stockage d'un profil systeme protege par permissions n'est pas equivalent au chiffrement
DPAPI Windows. L'assistant ne lit ni n'affiche les secrets. Le profil enregistre sur disque
n'est pas modifie par les essais d'IP. Ne pas utiliser deux sessions en parallele.
Une coupure de courant ou SIGKILL ne permet pas de garantir le nettoyage ; les clones
sont non persistants et disparaissent au redemarrage de NetworkManager.

## Utilitaire fourni corrige

`Enterprise_Network-linux-Maroc_Campus_Connecte.py` est la copie du fichier fourni par
l'utilisateur, provenant de https://campusconnecte.online/Linux.html. L'erreur de syntaxe
sur les guillemets autour de sudo a ete corrigee. Le lancement est maintenant protege par __main__ pour eviter une installation lors d'un import. Les parametres TTLS/PAP, autorites de
certification et noms de serveurs du fichier fourni sont conserves.
Cet utilitaire remplace les profils Campus existants : l'assistant ne le lance qu'apres
confirmation. Preferer NetworkManager ; le mode de secours wpa_supplicant de cet ancien
utilitaire peut enregistrer le mot de passe en clair. Ce fichier n'est pas une nouvelle
version officielle et ses dependances restent propres a la distribution.

La validation automatisee utilise des commandes reseau simulees. La connexion 802.1X,
les permissions Polkit et le DHCP reel doivent etre verifies sur un ordinateur Linux
avec Wi-Fi au campus ; WSL ne fournit pas ce test materiel.
