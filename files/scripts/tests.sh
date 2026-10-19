#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

IMPORTANT_PACKAGES=(
    code
    gnome-keyring
    greetd
    hyprland
    hyprland-uwsm
    kitty
    kvantum
    libvirt
    nautilus
    plasma-desktop
    plasma-integration
    qemu-kvm
    steam
    swtpm-tools
    tuigreet
    tuned-ppd
    uwsm
    vicinae
    waybar
)

for package in "${IMPORTANT_PACKAGES[@]}"; do
    rpm -q "${package}" >/dev/null || { echo "Missing package: ${package}... Exiting"; exit 1 ; }
done

# these packages are supposed to be removed
# and are considered footguns
UNWANTED_PACKAGES=(
    firefox
    kio-extras-kf5
    nodejs24-docs
    pam-kwallet
    PackageKit
    plasma-discover-packagekit
    sddm
)

for package in "${UNWANTED_PACKAGES[@]}"; do
    if rpm -q "${package}" >/dev/null 2>&1; then
        echo "Unwanted package found: ${package}... Exiting"; exit 1
    fi
done

# Make sure this garbage never makes it to an image
if grep -l -s -E 'copr.fedorainfracloud.org/(sdegler|quadratech188)|packages.microsoft.com' /etc/yum.repos.d/*.repo; then
    echo "Third-party repo left in the image... Exiting"; exit 1
fi

grep -qx 'NoDisplay=true' /usr/share/wayland-sessions/hyprland.desktop
grep -qx 'OnlyShowIn=KDE;' /etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop
grep -qx 'NotShowIn=KDE;' /etc/xdg/autostart/blueman.desktop
test "$(systemctl get-default)" = graphical.target

grep -qx 'Enabled=false' /etc/xdg/kwalletrc
grep -qx 'LookAndFeelPackage=org.aeasesos.resolve.desktop' /etc/xdg/kdeglobals
grep -qx 'name=resolve' /etc/xdg/plasmarc
test -f /usr/share/plasma/desktoptheme/resolve/widgets/bar_meter_horizontal.svgz
fc-list : family | tr ',' '\n' | grep -x 'JetBrainsMonoNL Nerd Font' >/dev/null

test "$(GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.interface gtk-theme)" = "'adw-gtk3-dark'"
test "$(GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.interface gtk-enable-primary-paste)" = false
test "$(GSETTINGS_BACKEND=memory gsettings get org.blueman.general plugin-list)" = "['!ShowConnected', '!StatusIcon']"
test "$(XDG_CURRENT_DESKTOP=Hyprland GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.interface icon-theme)" = "'pixora'"
test "$(XDG_CURRENT_DESKTOP=KDE GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.interface icon-theme)" = "'Papirus-Dark'"

for dir in /var/lib/greetd /var/lib/swtpm-localca /var/lib/libvirt/images; do
    grep -q "^d ${dir} " /usr/lib/tmpfiles.d/aeases-os-var.conf
done

IMPORTANT_UNITS=(
    greetd.service
    keyd.service
    virtqemud.socket
    wheel-groups.service
)

for unit in "${IMPORTANT_UNITS[@]}"; do
    if ! systemctl is-enabled "$unit" 2>/dev/null | grep -q "^enabled$"; then
        echo "${unit} is not enabled"
        exit 1
    fi
done

IMPORTANT_USER_UNITS=(
    airplay-bridge.service
    deepfilter-mic.service
    vicinae.service
)

for unit in "${IMPORTANT_USER_UNITS[@]}"; do
    if ! systemctl --global is-enabled "$unit" 2>/dev/null | grep -q "^enabled$"; then
        echo "${unit} is not enabled for users"
        exit 1
    fi
done

# the venv takes cryptography, requests, cffi... from the image's RPMs
/usr/lib/airplay-bridge/bin/python -c 'import airplay_bridge.bridge, airplay_bridge.sender'
command -v avahi-browse pactl >/dev/null

# is-enabled exits 1 for a disabled unit
if [[ "$(systemctl is-enabled libvirtd.service 2>/dev/null || true)" != disabled ]]; then
    echo "libvirtd.service is not disabled"
    exit 1
fi

# binaries not installed by dnf aren't checked for missing libraries until they run
set +x
UNRESOLVED=()
while read -r file; do
    [[ $(head -c 4 "$file" 2>/dev/null | tr -d '\0') == $'\x7fELF' ]] || continue
    if missing=$(ldd "$file" 2>&1 | grep 'not found'); then
        UNRESOLVED+=("${file}:"$'\n'"${missing}")
    fi
done < <(comm -13 <(rpm -qa --qf '[%{FILENAMES}\n]' | sort -u) \
                  <(find /usr/bin /usr/sbin /usr/libexec /usr/lib /usr/lib64 /usr/share -xdev -type f \
                        \( -perm -u+x -o -name '*.so' -o -name '*.so.*' \) 2>/dev/null | sort))
if (( ${#UNRESOLVED[@]} )); then
    printf 'Unresolved libraries in %s\n' "${UNRESOLVED[@]}"
    echo "... Exiting"; exit 1
fi
set -x

bootc container lint

echo "::endgroup::"
