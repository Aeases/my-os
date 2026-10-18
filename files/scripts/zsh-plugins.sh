#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

DEST=/usr/share/zsh/plugins
mkdir -p "$DEST"

clone() {
  git clone --quiet --depth 1 "https://github.com/$1.git" "$DEST/$2"
  rm -rf "$DEST/$2/.git"
}

clone romkatv/powerlevel10k powerlevel10k
clone jeffreytse/zsh-vi-mode zsh-vi-mode
clone zdharma-continuum/history-search-multi-word history-search-multi-word
clone zsh-users/zsh-completions zsh-completions
clone hlissner/zsh-autopair zsh-autopair
clone zdharma-continuum/fast-syntax-highlighting fast-syntax-highlighting

cd "$DEST/powerlevel10k"
zsh -fc 'for f in *.zsh-theme internal/*.zsh; do zcompile -R -- $f.zwc $f || exit; done'
cd gitstatus
zsh -fc 'for f in *.zsh install; do zcompile -R -- $f.zwc $f || exit; done'
GITSTATUS_DAEMON= GITSTATUS_CACHE_DIR="$PWD/usrbin" ./install -f
ls usrbin/gitstatusd-*
