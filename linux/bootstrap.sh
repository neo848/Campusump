#!/bin/sh
# Installation publique : tout telecharger avant d'executer l'installateur local.
main() {
    command -v python3 >/dev/null 2>&1 || { echo 'Python 3 est requis.' >&2; return 1; }
    python3 - <<'PY'
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import urllib.request

repo = 'neo848/Campusump'
files = ('install.py', 'campuse.py', 'zones.json', 'Enterprise_Network-linux-Maroc_Campus_Connecte.py')
try:
    request = urllib.request.Request('https://api.github.com/repos/' + repo + '/commits/main', headers={'User-Agent': 'campuse-installer'})
    with urllib.request.urlopen(request, timeout=30) as response:
        revision = json.load(response)['sha']
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise RuntimeError('Revision GitHub invalide.')
    with tempfile.TemporaryDirectory(prefix='campuse-install-') as temporary:
        directory = Path(temporary)
        for filename in files:
            url = f'https://raw.githubusercontent.com/{repo}/{revision}/linux/{filename}'
            with urllib.request.urlopen(url, timeout=30) as response:
                (directory / filename).write_bytes(response.read())
        result = subprocess.run([sys.executable, str(directory / 'install.py')])
        sys.exit(result.returncode)
except Exception as exc:
    sys.exit('Installation impossible (depot public requis) : ' + str(exc))
PY
}
main
