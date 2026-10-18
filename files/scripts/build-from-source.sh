#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

OUT=/out
PATCHES="$(cd "$(dirname "$0")" && pwd)/patches"

WORK=$(mktemp -d)
cd "$WORK"

dnf -y install --setopt=install_weak_deps=False \
        gcc gcc-c++ make meson ninja-build git cargo rust pkgconf-pkg-config scdoc \
        wayland-devel wayland-protocols-devel libxkbcommon-devel \
        cairo-devel pango-devel freetype-devel harfbuzz-devel lz4-devel

fetch() { # fetch <url> <tag> <dir>
  git clone --quiet --depth 1 --branch "$2" "$1" "$3"
}

fetch https://github.com/rvaiya/keyd.git v2.6.0 keyd
make -C keyd
make -C keyd install DESTDIR="$OUT" PREFIX=/usr FORCE_SYSTEMD=1

fetch https://github.com/philj56/tofi.git v0.9.1 tofi
meson setup tofi/build tofi --prefix=/usr --buildtype=release
meson compile -C tofi/build
DESTDIR="$OUT" meson install -C tofi/build

fetch https://github.com/Linus789/wl-clip-persist.git v0.5.0 wl-clip-persist
cargo build --locked --release --manifest-path wl-clip-persist/Cargo.toml
install -Dm755 wl-clip-persist/target/release/wl-clip-persist -t "$OUT/usr/bin"

dnf -y install --setopt=install_weak_deps=False libxkbcommon-x11-devel fontconfig-devel systemd-devel
fetch https://github.com/phisch/psst.git v0.2.0 psst
git -C psst apply "$PATCHES/psst-action-theme.patch"
cargo build --locked --release --manifest-path psst/Cargo.toml
install -Dm755 psst/target/release/psst-{polkit-agent,keyring-prompter,pinentry} -t "$OUT/usr/bin"

fetch https://codeberg.org/LGFae/awww.git v0.12.1 awww
cargo build --locked --release --manifest-path awww/Cargo.toml
install -Dm755 awww/target/release/awww awww/target/release/awww-daemon -t "$OUT/usr/bin"

dnf -y install --setopt=install_weak_deps=False python3-pip
echo "waypaper==2.9 --hash=sha256:3455cb7b120a3b6bcaeddafb8e18bb415cd40187c9d9be106e528ba93b0e529f" > waypaper.txt
pip install --root-user-action=ignore --no-deps --require-hashes --root "$OUT" --prefix /usr -r waypaper.txt

echo "discover-overlay==0.7.9 --hash=sha256:d7815ec315b4a69449bb21abd735369caf545db690ddcfed4eeb520ef027f820" > discover.txt
pip install --root-user-action=ignore --no-deps --require-hashes --root "$OUT" --prefix /usr -r discover.txt

dnf -y install --setopt=install_weak_deps=False pam-devel stb_image_resize2-devel stb_image_write-devel \
        'pkgconfig(cairo)' 'pkgconfig(cairo-ft)' 'pkgconfig(egl)' 'pkgconfig(epoxy)' \
        'pkgconfig(fontconfig)' 'pkgconfig(freetype2)' 'pkgconfig(gio-2.0)' 'pkgconfig(glesv2)' \
        'pkgconfig(glib-2.0)' 'pkgconfig(gobject-2.0)' 'pkgconfig(harfbuzz)' 'pkgconfig(jemalloc)' \
        'pkgconfig(libcurl)' 'pkgconfig(libical)' 'pkgconfig(libjxl)' 'pkgconfig(libjxl_threads)' \
        'pkgconfig(libpipewire-0.3)' 'pkgconfig(libqalculate)' 'pkgconfig(librsvg-2.0)' \
        'pkgconfig(libsecret-1)' 'pkgconfig(libsodium)' 'pkgconfig(libwebp)' 'pkgconfig(libwebpdemux)' \
        'pkgconfig(libxml-2.0)' 'pkgconfig(md4c)' 'pkgconfig(nlohmann_json)' 'pkgconfig(pango)' \
        'pkgconfig(pangocairo)' 'pkgconfig(pangoft2)' 'pkgconfig(polkit-agent-1)' \
        'pkgconfig(polkit-gobject-1)' 'pkgconfig(sdbus-c++)' 'pkgconfig(sndfile)' \
        'pkgconfig(tomlplusplus)' 'pkgconfig(wayland-client)' 'pkgconfig(wayland-egl)' \
        'pkgconfig(wayland-protocols)' 'pkgconfig(wayland-scanner)' 'pkgconfig(wireplumber-0.5)' \
        'pkgconfig(xkbcommon)'
git init --quiet noctalia
git -C noctalia fetch --quiet --depth 1 https://github.com/noctalia-dev/noctalia-shell.git \
        273439338a50c51bdef105ba243175d7a914965a
git -C noctalia checkout --quiet FETCH_HEAD
git -C noctalia apply "$PATCHES/noctalia-local.patch"
meson setup noctalia/build noctalia --prefix=/usr --buildtype=release -Dtests=disabled
meson compile -C noctalia/build
DESTDIR="$OUT" meson install -C noctalia/build

cd /
rm -rf "$WORK"
