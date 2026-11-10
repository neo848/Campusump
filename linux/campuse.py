#!/usr/bin/env python3
"""Assistant Campus Connecte pour Linux/NetworkManager. Aucun secret propre au script."""
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import random
import shutil
import signal
import socket
import subprocess
import sys
import time
import uuid

HERE = Path(__file__).resolve().parent
SSID = 'Campus Connecte'
REPAIR_ALLOWED = set()
ACTIVATION_WAIT = 90
DHCP_TIMEOUT = 30


def command(args, check=True, interactive=False, timeout=35):
    result = subprocess.run(args, text=True, capture_output=not interactive,
                            env={**os.environ, 'LC_ALL': 'C'}, timeout=timeout)
    if check and result.returncode:
        raise RuntimeError((result.stderr or 'Commande refusee ou connexion impossible.').strip())
    return result


def nm(*args, wait=20, **kwargs):
    # Le garde-fou Python doit laisser nmcli terminer son propre delai.
    kwargs.setdefault('timeout', wait + 15)
    return command(['nmcli', '--wait', str(wait), *args], **kwargs)


def activate(profile, device, ask=False):
    options = ('--ask',) if ask else ()
    try:
        return nm(*options, 'connection', 'up', 'uuid', profile, 'ifname', device,
                  wait=ACTIVATION_WAIT, interactive=ask, check=False)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError('Activation Wi-Fi sans reponse dans le delai imparti. '
                           'Verifiez NetworkManager, le signal et le compte Campus.') from exc


def activation_error(result, state, reason):
    message = (f'Delai d\'activation depasse ({ACTIVATION_WAIT} secondes).'
               if result.returncode == 3 else 'Activation Wi-Fi non aboutie.')
    return RuntimeError(f'{message} Etat NetworkManager : {state} ; raison : {reason}. '
                        'Verifiez le signal, le compte et le certificat. '
                        'Aucune IP statique forcee.')


def field(name, *args):
    return nm('-g', name, *args).stdout.strip()


def active(device):
    return field('GENERAL.CON-UUID', 'device', 'show', device).replace('--', '')


def connection_state(device):
    """Pas de ping global : les essais TCP sont lies a l'adresse de cette interface."""
    data = json.loads(command(['ip', '-j', '-4', 'address', 'show', 'dev', device]).stdout)
    addresses = [ipaddress.ip_address(a['local']) for d in data for a in d.get('addr_info', [])
                 if a.get('family') == 'inet']
    valid = [a for a in addresses if not a.is_link_local and not a.is_loopback]
    if not valid:
        return 'apipa' if any(a.is_link_local for a in addresses) else 'no-address'
    for address in valid:
        for host in ('1.1.1.1', '8.8.8.8'):
            try:
                with socket.socket() as client:
                    client.settimeout(1)
                    client.bind((str(address), 0))
                    # Linux : impose aussi l'interface si les privileges le permettent.
                    try:
                        client.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, device.encode() + b'\0')
                    except PermissionError:
                        pass
                    client.connect((host, 443))
                    return 'online'
            except OSError:
                pass
    return 'uncertain'


def preserve(device):
    state = connection_state(device)
    if state == 'online':
        print('Connexion operationnelle : aucun changement.')
        return True
    if state == 'uncertain':
        if device in REPAIR_ALLOWED:
            return False
        keep = input('IP valide, Internet non confirme. Conserver ? [O/n] ').lower() != 'n'
        if not keep:
            REPAIR_ALLOWED.add(device)
        return keep
    return False


def choose(items, label):
    if not items:
        raise RuntimeError('Aucun element disponible : ' + label)
    for index, (_, title) in enumerate(items, 1):
        print(f'{index}. {title}')
    while True:
        value = input(label + ' (0 = annuler) : ')
        if value == '0':
            raise KeyboardInterrupt
        if value.isdigit() and 1 <= int(value) <= len(items):
            return items[int(value) - 1][0]


def wifi_device():
    rows = nm('-t', '-f', 'DEVICE,TYPE', 'device', 'status').stdout.splitlines()
    devices = [row.rsplit(':', 1)[0] for row in rows if row.endswith(':wifi')]
    return devices[0] if len(devices) == 1 else choose([(d, d) for d in devices], 'Interface Wi-Fi')


def profiles():
    found = []
    for ident in field('UUID', 'connection', 'show').splitlines():
        if field('connection.type', 'connection', 'show', 'uuid', ident) != '802-11-wireless':
            continue
        if field('802-11-wireless.ssid', 'connection', 'show', 'uuid', ident) != SSID:
            continue
        if field('connection.id', 'connection', 'show', 'uuid', ident).startswith('campuse-session-'):
            continue
        email = field('802-1x.identity', 'connection', 'show', 'uuid', ident)
        masked = email[:1] + '***@' + email.split('@', 1)[1] if '@' in email else 'compte enregistre'
        found.append((ident, masked))
    return found


def configure_account():
    print('Configuration initiale/remplacement du compte avec l\'utilitaire fourni.')
    print('Les anciens profils Campus seront remplaces. Les certificats sont conserves dans la configuration.')
    if input('Continuer ? [o/N] ').lower() != 'o':
        return
    command([sys.executable, str(HERE / 'Enterprise_Network-linux-Maroc_Campus_Connecte.py')],
            interactive=True, timeout=None)


class Session:
    def __init__(self, device, original):
        self.device, self.original = device, original
        self.temporary = None
        self.changed = False
        self.clone_name = None

    def prepare(self):
        name = 'campuse-session-' + str(uuid.uuid4())
        self.clone_name = name
        nm('connection', 'clone', '--temporary', 'uuid', self.original, name)
        self.temporary = field('connection.uuid', 'connection', 'show', 'id', name)
        nm('connection', 'modify', '--temporary', 'uuid', self.temporary,
           'connection.autoconnect', 'no')

    def try_dhcp(self):
        print(f'Essai DHCP et DNS automatiques (activation Wi-Fi : {ACTIVATION_WAIT} s maximum, '
              f'dont DHCP : {DHCP_TIMEOUT} s)...')
        nm('connection', 'modify', '--temporary', 'uuid', self.temporary,
           'ipv4.method', 'auto', 'ipv4.addresses', '', 'ipv4.gateway', '',
           'ipv4.dns', '', 'ipv4.ignore-auto-dns', 'no', 'ipv4.dhcp-timeout', str(DHCP_TIMEOUT))
        self.changed = True
        result = activate(self.temporary, self.device, ask=True)
        if preserve(self.device):
            return True
        state = field('GENERAL.STATE', 'device', 'show', self.device)
        reason = field('GENERAL.REASON', 'device', 'show', self.device)
        # 70/100 : configuration IP / connexion active ; 5/6 : echec de configuration IP.
        # Un timeout seul ne prouve pas que l'authentification a reussi.
        if state.partition(' ')[0] not in ('70', '100') and reason.partition(' ')[0] not in ('5', '6'):
            raise activation_error(result, state, reason)
        print('DHCP sans connexion utilisable : choix de la zone pour une IP statique.')
        return False

    def apply(self, address, zone):
        nm('connection', 'modify', '--temporary', 'uuid', self.temporary,
           'ipv4.method', 'manual', 'ipv4.addresses', f"{address}/{zone['cidr']}",
           'ipv4.gateway', zone['gateway'], 'ipv4.dns', '8.8.8.8,8.8.4.4',
           'ipv4.ignore-auto-dns', 'yes')
        self.changed = True  # Avant la commande : meme une activation interrompue exige le nettoyage.
        result = activate(self.temporary, self.device, ask=True)
        if result.returncode:
            reason = field('GENERAL.REASON', 'device', 'show', self.device).split()[0]
            if reason not in ('5', '6'):
                raise RuntimeError('Activation refusee : verifiez compte, certificat et signal Wi-Fi.')

    def close(self):
        if not self.temporary:
            if self.clone_name:
                nm('connection', 'delete', 'id', self.clone_name, check=False)
            return
        errors = []
        try:
            current = active(self.device)
            # Ne pas deconnecter un autre reseau choisi entre-temps par l'utilisateur.
            if self.changed and current in ('', self.temporary):
                print('Retour IP DHCP et DNS automatiques...')
                nm('connection', 'modify', '--temporary', 'uuid', self.original,
                   'ipv4.method', 'auto', 'ipv4.addresses', '', 'ipv4.gateway', '',
                   'ipv4.dns', '', 'ipv4.ignore-auto-dns', 'no')
                result = activate(self.original, self.device)
                if result.returncode:
                    detail = (f'delai de {ACTIVATION_WAIT} secondes depasse'
                              if result.returncode == 3 else
                              (result.stderr or 'activation refusee').strip())
                    raise RuntimeError('Reconnexion au profil d\'origine impossible : ' + detail)
        except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
            errors.append(str(exc))
        finally:
            try:
                nm('connection', 'delete', 'uuid', self.temporary)
            except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
                errors.append('Suppression du profil temporaire impossible : ' + str(exc))
        if errors:
            raise RuntimeError(' ; '.join(errors))


def repair(device, original, dhcp_failed=False, session=None):
    if preserve(device):
        return
    if not shutil.which('arping'):
        raise RuntimeError('Installez iputils-arping : verification des conflits IP obligatoire.')
    # Refuser le recours a une IP statique pour une erreur d'authentification.
    state = field('GENERAL.STATE', 'device', 'show', device).split()[0]
    if state not in ('70', '100') and not dhcp_failed:
        raise RuntimeError('Wi-Fi non authentifie / configuration IP non atteinte. Verifiez le compte avant de choisir une IP.')
    zone_data = json.loads((HERE / 'zones.json').read_text(encoding='utf-8'))
    zone = choose([(z, z['name']) for z in zone_data], 'Votre zone sur le campus')
    owned = session is None
    session = session or Session(device, original)
    try:
        if owned:
            session.prepare()
        tested = set()
        for _ in range(10):
            if not session.changed and preserve(device):
                return
            if session.changed and connection_state(device) == 'online':
                input('Connexion retablie. Entree ou Ctrl+C pour terminer la session : ')
                return
            prefix = zone['gateway'].split('.')[:2]
            while True:
                ip = '.'.join(prefix + [str(random.randint(*zone['active_octet3_range'])),
                                       str(random.randint(*zone['active_octet4_range']))])
                if ip not in tested:
                    tested.add(ip)
                    break
            if ipaddress.ip_address(ip) not in ipaddress.ip_network(f"{zone['gateway']}/{zone['cidr']}", strict=False):
                raise RuntimeError('Plage IP incompatible avec la passerelle.')
            # iputils arping -D : 0 = aucune reponse, 1 = conflit, >1 = erreur.
            probe = command(['sudo', 'arping', '-D', '-I', device, '-c', '2', '-w', '3', ip], check=False)
            if probe.returncode == 1:
                print('Adresse occupee, autre candidate...')
                continue
            if probe.returncode:
                raise RuntimeError('Verification ARP impossible ; aucune IP appliquee.')
            print('Essai IP :', ip)
            session.apply(ip, zone)
            for _ in range(5):
                time.sleep(2)
                if connection_state(device) == 'online':
                    print('Connexion retablie. Gardez ce terminal ouvert pour cette session.')
                    input('Entree ou Ctrl+C pour quitter et restaurer DHCP/DNS : ')
                    return
        print('Aucune connexion valide apres 10 essais. Retour en automatique.')
    finally:
        if owned:
            finish_session(session)


def finish_session(session):
    original_error = sys.exc_info()[1]
    old = {sig: signal.signal(sig, signal.SIG_IGN) for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)}
    try:
        try:
            session.close()
        except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
            if original_error is None:
                raise
            # Garder l'erreur initiale (ou l'interruption), et signaler aussi le nettoyage.
            print('Attention, nettoyage incomplet : ' + str(exc), file=sys.stderr)
    finally:
        for sig, handler in old.items():
            signal.signal(sig, handler)


def main():
    if sys.platform != 'linux':
        raise RuntimeError('Cet assistant necessite Linux avec NetworkManager.')
    for binary in ('nmcli', 'ip'):
        if not shutil.which(binary):
            raise RuntimeError('Commande requise : ' + binary)
    if field('RUNNING', 'general') != 'running':
        raise RuntimeError('NetworkManager doit etre actif.')
    device = wifi_device()
    if preserve(device):
        return
    available = profiles()
    if not available:
        configure_account()
        available = profiles()
    if not available:
        return
    profile = choose(available + [('new', 'Configurer/remplacer le compte')], 'Compte Campus')
    if profile == 'new':
        configure_account()
        return
    current = active(device)
    if current and current != profile:
        if input('Un autre profil est actif. Passer au Campus ? [o/N] ').lower() != 'o':
            return
    if preserve(device):
        return
    session = Session(device, profile)
    try:
        session.prepare()
        if session.try_dhcp():
            input('Connexion conservee. Gardez ce terminal ouvert. '
                  'Entree ou Ctrl+C pour terminer et restaurer DHCP/DNS : ')
            return
        repair(device, profile, dhcp_failed=True, session=session)
    finally:
        finish_session(session)


def interrupted(signum, frame):
    raise KeyboardInterrupt


if __name__ == '__main__':
    try:
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(sig, interrupted)
        lockdir = Path.home() / '.cache' / 'campuse'
        lockdir.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (lockdir / 'session.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            main()
    except BlockingIOError:
        print('Une session campuse est deja ouverte.', file=sys.stderr)
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print('\nSession terminee.')
    except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
        print('Erreur :', exc, file=sys.stderr)
        sys.exit(1)
