#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

COMMIT="58d3585a99a5cb7771d7451962e1b7dcd9abf902"

git init --quiet pixora-icons
git -C pixora-icons fetch --quiet --depth 1 https://github.com/Aeases/pixora-icons.git "$COMMIT"
git -C pixora-icons checkout --quiet FETCH_HEAD
cp -a pixora-icons/pixora /usr/share/icons/pixora
gtk-update-icon-cache -qf /usr/share/icons/pixora
rm -rf pixora-icons
