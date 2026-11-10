# Campus Connecte — Linux

Cible : distributions avec Python 3.9+ et NetworkManager (Ubuntu, Mint, Debian, Kali).
Les systemes utilisant uniquement systemd-networkd ou iwd ne sont pas pris en charge.

Le [README principal](../README.md#installation-linux--kali-ubuntu-debian-mint) decrit
le parcours complet, avec l'installation en ligne ou par ZIP et les exemples de menus.
Ce guide precise le lancement local, les etapes reseau et le diagnostic.

## Installation

Sur Debian/Ubuntu/Mint/Kali, installer les dependances si elles manquent :

```sh
sudo apt update
sudo apt install python3 python3-dbus python3-distro network-manager iproute2 iputils-arping wget
```

Puis, depuis la racine du depot extrait, installer avec votre utilisateur habituel :

```sh
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

## Lancement au quotidien

Au campus, activer le Wi-Fi et se placer a portee du reseau **Campus Connecte**.
Verifier les prerequis depuis un terminal :

```sh
python3 --version
nmcli general status
nmcli device status
```

Python doit etre en version 3.9 ou superieure. NetworkManager doit repondre et une
interface de type `wifi` doit apparaitre. Une interface Ethernet ou virtuelle ne
remplace pas une carte Wi-Fi pour la connexion au campus.

Lancer ensuite, **sans sudo**, dans un nouveau terminal :

```sh
campuse
```

Le nom se termine par un **e** : `campus` n'est pas la commande installee. Si l'alias
n'est pas disponible, le lanceur peut etre appele directement :

```sh
~/.local/bin/campuse
```

Pour executer les sources sans installer de commande, depuis la racine du depot :

```sh
python3 linux/campuse.py
```

Conserver `zones.json` et l'utilitaire de configuration dans le meme dossier que
`campuse.py`. Le lancement direct utilise ces sources ; la commande `campuse` utilise
leur copie dans `~/.local/share/campuse`. Relancer `sh INSTALLER.sh` depuis `linux`
apres une mise a jour pour actualiser cette copie, une fois la session precedente terminee.

## Fonctionnement prevu, etape par etape

1. Choix de l'interface si plusieurs cartes Wi-Fi sont disponibles.
2. Test TCP sur l'adresse de cette interface. Une connexion fonctionnelle reste intacte.
   Une IP valide mais non verifiee est conservee par defaut (portail/filtrage possible).
   `Connexion operationnelle : aucun changement.` suivi d'un retour au terminal est
   donc normal. A l'invite `Conserver ? [O/n]`, Entree conserve et `n` poursuit les essais.
3. Reutilisation d'un profil Campus existant, avec email masque, ou installation/remplacement
   explicite du compte via l'utilitaire fourni. Ne jamais utiliser une IP statique pour
   contourner une erreur d'authentification.
   Saisir le numero affiche devant le compte, puis Entree ; `0` annule un menu.
   Les numeros dependent des profils disponibles. Sans profil, confirmer avec `o` et
   suivre l'utilitaire pour creer le compte. L'assistant recherche ensuite les profils.
   Si l'option de remplacement est choisie dans le menu des comptes, relancer `campuse`
   apres la configuration. A une demande de passage depuis un autre profil actif,
   `o` accepte et Entree annule le changement.
4. Essai DHCP/DNS automatiques, meme en APIPA : jusqu'a 90 secondes pour l'activation
   Wi-Fi (association, authentification et configuration IP), avec un delai DHCP de
   30 secondes. En cas d'echec IP apres authentification, choix de la zone,
   verification ARP des conflits, puis au maximum 10 IP candidates. `sudo arping` peut
   demander le mot de passe Linux ; NetworkManager utilise ses autorisations habituelles.
5. Les essais utilisent un clone temporaire du profil, avec reconnexion possible lors du
   changement d'IP. Garder le terminal ouvert pendant la session reparee.
   Choisir la zone correspondant a l'emplacement reel : FSO Bibliotheque, FSO Solo,
   FSO Master, Qanon/Droit, FSJESO ou ENSAO. Les plages sont definies dans `zones.json`.
   Une adresse occupee est ecartee ; si le controle ARP est impossible, la candidate
   n'est pas appliquee. Si aucune connexion n'est obtenue apres les dix candidates,
   l'assistant termine les essais et engage le retour en automatique.
6. Entree/Ctrl+C restaure DHCP et DNS automatiques puis supprime le clone temporaire.
   Si l'utilisateur a change de reseau entre-temps, ce nouveau reseau reste intact.
   La session reste ouverte aussi apres une reussite DHCP. La reconnexion au profil
   d'origine peut prendre jusqu'a 90 secondes. Une erreur de nettoyage est signalee
   separement pour ne pas masquer l'erreur initiale.

**Pendant une session reparee, Entree a l'invite de fin termine la session.** L'attente
est volontaire ; laisser le terminal ouvert pour continuer a utiliser la connexion.
Attendre la fin de `Retour IP DHCP et DNS automatiques...` avant de relancer l'assistant.
Le retour en automatique peut interrompre l'acces, notamment si une IP statique etait
necessaire et que DHCP ne fonctionne toujours pas.

Les delais de 90 secondes s'appliquent a chaque activation, pas a toute la session.
Les controles reseau, les reponses aux invites et les essais d'adresses ajoutent du
temps. Le programme laisse une marge supplementaire a `nmcli` avant d'interrompre un
processus bloque ; un depassement ne permet pas, seul, d'identifier la cause reseau.

## Profils et identifiants

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

## Validation et tests

La validation automatisee utilise des commandes reseau simulees. La connexion 802.1X,
les permissions Polkit et le DHCP reel doivent etre verifies sur un ordinateur Linux
avec Wi-Fi au campus ; WSL ne fournit pas ce test materiel.

Depuis la racine du depot, lancer les tests sans modifier le reseau :

```sh
python3 -m unittest discover -s linux/tests -v
```

Les tests couvrent les delais d'activation, les conditions de recours a une IP statique,
la conservation d'une connexion DHCP jusqu'a la sortie et les erreurs de restauration.

## Diagnostic apres un echec

En cas de delai depasse, le programme affiche l'etat et la raison fournis par
NetworkManager quand ils sont disponibles. Un timeout ne prouve pas un echec DHCP :
le programme refuse l'IP statique si la configuration IP n'a pas ete atteinte et
qu'aucun echec IP n'est identifie. Pour diagnostiquer apres un echec :

```sh
nmcli -f GENERAL.STATE,GENERAL.REASON,IP4.ADDRESS,IP4.GATEWAY device show
sudo journalctl -u NetworkManager --since "10 minutes ago" --no-pager -n 150
```

Masquer les identifiants et informations personnelles avant de partager les journaux.

Si le message d'activation indique encore **15 secondes**, la copie executee utilise
l'ancien delai. Fermer la session, recuperer les sources corrigees et relancer
`sh INSTALLER.sh` depuis leur dossier `linux`. L'installation en ligne recupere la
version presente sur GitHub ; une modification locale doit y etre publiee pour etre
distribuee par cette methode.
