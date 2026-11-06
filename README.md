# Campus Connecte — Windows

Assistant Wi-Fi pour le campus UMP Oujda (Windows 10 et 11).

## Installation

1. Cliquez sur **Code → Download ZIP**, puis **Extraire tout**.
2. Double-cliquez sur **INSTALLER.bat**.
3. Lancez **Campus Connecte** depuis le raccourci sur le Bureau et acceptez la demande administrateur.

Sans installation, double-cliquez sur **Lancer_Campus_Wifi.bat**.
Gardez les fichiers ensemble : seul `campus_config.json` est facultatif pour le lancement direct.

## Utilisation

- **Compte personnel [2]** : sauvegarde chiffree Windows, email masque, reutilisation ou remplacement du compte.
- **0 ou Ctrl+C** : quitte et restaure IP via DHCP et DNS automatiques uniquement sur les interfaces modifiees pendant cette session.
- L'installation ne modifie pas le Wi-Fi. La restauration a la sortie peut interrompre temporairement la connexion.

Le compte chiffre reste lie au meme utilisateur Windows sur le meme ordinateur.
Une fermeture forcee du processus ou une coupure de courant ne garantit pas le nettoyage.

Avant toute configuration, le script verifie la connexion de l'interface choisie
avec deux tests TCP courts (sans changer IP, DNS ou compte Wi-Fi).
Une connexion operationnelle est conservee. Une IP valide dont l'acces Internet
reste incertain est conservee par defaut, avec confirmation avant reconfiguration.
En cas d'APIPA (`169.254.x.x`), choisissez votre zone : la recherche d'IP statique
commence directement, sans nouvelle attente DHCP. La zone reste necessaire pour
utiliser la bonne plage IP.