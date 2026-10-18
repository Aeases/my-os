#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

VERSION="0.4.3"
SHA256="85b6598284fc639f2a282584461d05e2090b79bdf3ec949d2a5e5d3dc655dde4"

curl -fsSL -o "netmuxd.tar.gz" \
        "https://github.com/jkcoxson/netmuxd/releases/download/v${VERSION}/netmuxd-x86_64-unknown-linux-gnu.tar.gz"
echo "${SHA256}  netmuxd.tar.gz" | sha256sum -c -

tar -xzf "netmuxd.tar.gz" netmuxd
install -m 0755 netmuxd /usr/bin/netmuxd

rm netmuxd netmuxd.tar.gz
