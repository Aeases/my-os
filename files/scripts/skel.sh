#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

rm -f /etc/skel/.bashrc /etc/skel/.bash_profile /etc/skel/.bash_logout \
      /etc/skel/.zshrc /etc/skel/.zprofile
sed -i -e 's|^SHELL=.*|SHELL=/usr/bin/zsh|' -e 's|^HOME=.*|HOME=/home|' /etc/default/useradd
grep -qx 'SHELL=/usr/bin/zsh' /etc/default/useradd
grep -qx 'HOME=/home' /etc/default/useradd
