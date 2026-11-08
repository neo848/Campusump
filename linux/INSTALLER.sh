#!/bin/sh
# Compatible avec bash, zsh et sh ; le moteur Python ne depend pas du shell.
set -eu
cd -- "$(dirname -- "$0")"
exec python3 ./install.py
