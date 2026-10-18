#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

wget -O "papirus.tar.gz" \
        "https://github.com/PapirusDevelopmentTeam/papirus-folders/archive/master.tar.gz"
tar -xzf "papirus.tar.gz"

bash papirus-folders-master/papirus-folders -t Papirus-Dark -C yaru

rm -rf papirus-folders-master
rm papirus.tar.gz
