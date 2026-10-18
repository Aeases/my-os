#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

WORK=$(mktemp -d)
cd "$WORK"

get() { # get <url> <sha256> <file>
  curl -fsSL -o "$3" "$1"
  echo "$2  $3" | sha256sum -c -
}

# wayscriber
get https://github.com/devmobasa/wayscriber/releases/download/v0.9.25/wayscriber-x86_64.rpm \
    ce1d412a7a03d91eb6917942ba9a42048a2f4bbac0f9c1f395f47e4247493ba0 wayscriber-x86_64.rpm
dnf -y install --nogpgcheck ./wayscriber-x86_64.rpm # unsigned upstream RPM; checksum verified above

# DeepFilterNet LADSPA plugin for the deepfilter-mic PipeWire filter.
get https://github.com/Rikorose/DeepFilterNet/releases/download/v0.5.6/libdeep_filter_ladspa-0.5.6-x86_64-unknown-linux-gnu.so \
    2ca3205c2911d389604a826a240e745597d50252b5cab81c8248252b335e2236 libdeep_filter_ladspa.so
install -Dm755 libdeep_filter_ladspa.so -t /usr/lib/ladspa
install -d /usr/lib64/ladspa
ln -s ../../lib/ladspa/libdeep_filter_ladspa.so /usr/lib64/ladspa/libdeep_filter_ladspa.so

# Helium browser.
get https://github.com/imputnet/helium-linux/releases/download/0.19.2.1/helium-0.19.2.1-x86_64_linux.tar.xz \
    707cf319e3a3d2aa061ca15d754877bd18b8b289208738c829fcb0873bc7ecdb helium.tar.xz
mkdir -p /usr/lib/helium
tar -xJf helium.tar.xz -C /usr/lib/helium --strip-components=1
ln -s ../lib/helium/helium-wrapper /usr/bin/helium
install -Dm644 /usr/lib/helium/helium.desktop -t /usr/share/applications
install -Dm644 /usr/lib/helium/product_logo_256.png /usr/share/icons/hicolor/256x256/apps/helium.png

# JetBrainsMonoNL Nerd Font
get https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz \
    04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf JetBrainsMono.tar.xz
mkdir jetbrains-mono && tar -xJf JetBrainsMono.tar.xz -C jetbrains-mono
install -Dm644 jetbrains-mono/JetBrainsMonoNLNerdFont-*.ttf -t /usr/share/fonts/jetbrains-mono-nl-nerd-font
install -Dm644 jetbrains-mono/OFL.txt -t /usr/share/licenses/jetbrains-mono-nl-nerd-font
fc-cache -f /usr/share/fonts/jetbrains-mono-nl-nerd-font

# Discord.
curl -fsSL -o discord.tar.gz "https://discord.com/api/download?platform=linux&format=tar.gz"
tar -xzf discord.tar.gz
install -Dm755 Discord/updater_bootstrap -t /usr/share/discord
install -Dm755 Discord/discord -t /usr/bin
install -Dm644 Discord/discord.desktop -t /usr/share/applications
install -Dm644 Discord/discord.png /usr/share/icons/hicolor/256x256/apps/discord.png

cd /
rm -rf "$WORK"
