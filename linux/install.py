#!/usr/bin/env python3
"""Installation utilisateur : aucun changement reseau, aucune installation de paquet."""
import os
from pathlib import Path
import pwd
import shlex
import shutil
import sys

FILES = ('campuse.py', 'zones.json', 'Enterprise_Network-linux-Maroc_Campus_Connecte.py')


def install(source=None, home=None, shell=None):
    source = Path(source or Path(__file__).resolve().parent)
    home = Path(home or Path.home())
    shell = shell or os.environ.get('SHELL') or pwd.getpwuid(os.getuid()).pw_shell
    destination = home / '.local' / 'share' / 'campuse'
    binary = home / '.local' / 'bin' / 'campuse'
    for filename in FILES:
        if not (source / filename).is_file():
            raise RuntimeError('Fichier manquant : ' + filename)
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    binary.parent.mkdir(parents=True, exist_ok=True)
    for filename in FILES:
        target = destination / filename
        if (source / filename).resolve() != target.resolve():
            shutil.copyfile(source / filename, target)
        target.chmod(0o600)
    binary.write_text('#!/bin/sh\nexec python3 ' + shlex.quote(str(destination / 'campuse.py')) + ' "$@"\n', encoding='utf-8')
    binary.chmod(0o700)
    shell_name = Path(shell).name
    # Ajouter aussi l'alias aux configurations existantes en cas de changement de shell.
    rcfiles = {home / '.bashrc', Path(os.environ.get('ZDOTDIR', str(home))) / '.zshrc'}
    installed = []
    for rc in rcfiles:
        relevant = (rc.name == '.bashrc' and shell_name == 'bash') or (rc.name == '.zshrc' and shell_name == 'zsh')
        if not rc.exists() and not relevant:
            continue
        text = rc.read_text(encoding='utf-8') if rc.exists() else ''
        # Alias delimite, remplace a chaque mise a jour sans doublon.
        start, end = '# >>> campuse >>>', '# <<< campuse <<<'
        if start in text:
            first = text.index(start)
            last = text.find(end, first)
            if last < 0:
                raise RuntimeError('Bloc campuse incomplet dans ' + str(rc))
            text = text[:first] + text[last + len(end):].lstrip('\n')
        alias = 'alias campuse=' + shlex.quote(shlex.quote(str(binary)))
        text = text.rstrip() + '\n\n' + start + '\n' + alias + '\n' + end + '\n'
        rc.write_text(text, encoding='utf-8')
        installed.append(str(rc))
    print('Installation terminee. Shell detecte :', shell_name)
    print('Ouvrez un nouveau terminal puis tapez : campuse')
    if not installed:
        print('Shell non Bash/Zsh : utilisez', binary, 'ou ajoutez ~/.local/bin au PATH.')
    print('Aucun parametre Wi-Fi modifie. Compte reseau conserve dans NetworkManager.')
    return binary


if __name__ == '__main__':
    try:
        if sys.platform != 'linux':
            raise RuntimeError('Installation reservee a Linux.')
        if os.geteuid() == 0:
            raise RuntimeError('Lancez sans sudo pour installer dans votre compte utilisateur.')
        install()
    except (OSError, RuntimeError) as exc:
        sys.exit('Installation impossible : ' + str(exc))
