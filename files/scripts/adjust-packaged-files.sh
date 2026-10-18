#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# set_desktop_key <file> <key> <value>: set a key in a .desktop file
set_desktop_key() {
  local file=$1 key=$2 value=$3
  [[ -f "$file" ]] || { echo "adjust-packaged-files: $file is missing" >&2; exit 1; }
  sed -i -e "/^$key=/d" -e "/^\[Desktop Entry\]/a $key=$value" "$file"
}

# Boot into greetd, not a text console.
systemctl set-default graphical.target

systemd-hwdb update

[[ $(firewall-offline-cmd --get-default-zone) == FedoraWorkstation ]] \
  || firewall-offline-cmd --set-default-zone=FedoraWorkstation # errors if already set

set_desktop_key /etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop OnlyShowIn 'KDE;'

set_desktop_key /etc/xdg/autostart/blueman.desktop NotShowIn 'KDE;'

set_desktop_key /usr/share/wayland-sessions/hyprland.desktop NoDisplay true
