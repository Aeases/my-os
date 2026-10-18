#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

VERSION="0.8.3"

git clone --quiet --depth 1 --branch "$VERSION" \
        https://github.com/Stunkymonkey/nautilus-open-any-terminal.git nautilus-open-any-terminal
install -Dm644 nautilus-open-any-terminal/nautilus_open_any_terminal/nautilus_open_any_terminal.py \
        -t /usr/share/nautilus-python/extensions
install -Dm644 nautilus-open-any-terminal/nautilus_open_any_terminal/schemas/com.github.stunkymonkey.nautilus-open-any-terminal.gschema.xml \
        -t /usr/share/glib-2.0/schemas
rm -rf nautilus-open-any-terminal