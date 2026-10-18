# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

(( $+commands[dircolors] )) && eval "$(dircolors -b)"
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history # Persist history
HISTSIZE=1000000
SAVEHIST=1000000
setopt autocd autopushd pushdminus pushdsilent pushdtohome
setopt SHARE_HISTORY
# setopt INC_APPEND_HISTORY # Not needed with SHARE_HISTORY
unsetopt correct_all BEEP # Disable Autocorrect

# DIV: > Plugin loading <
# Plugins load from a local copy when this machine has one (baked into the
# aeases-os image, or a distro package), and are fetched with zinit otherwise,
# so this file works unchanged on any machine.
_plugin_dirs=(/usr/share/zsh/plugins /usr/share)

# _plugin_path <name> <file>: set REPLY to a local copy of the plugin's file
_plugin_path() {
  local d
  for d in $_plugin_dirs; do
    [[ -r $d/$1/$2 ]] && { REPLY=$d/$1/$2; return 0 }
  done
  return 1
}

# load_plugin <owner/repo> <file>: source the local copy, else load it with zinit
load_plugin() {
  if _plugin_path ${1:t} $2; then
    source $REPLY
    return
  fi
  if (( ! $+functions[zinit] )); then
    local zinit_home="${HOME}/.config/zinit/zinit.git"
    [[ -d $zinit_home/.git ]] || git clone https://github.com/zdharma-continuum/zinit.git "$zinit_home"
    source "$zinit_home/zinit.zsh"
  fi
  zinit ice depth"1" # git clone depth
  zinit light $1
}

# A local zsh-completions has to be on fpath before compinit
_plugin_path zsh-completions src && fpath=($REPLY $fpath)

# DIV: > Compinit Setup <
autoload -Uz compinit
zstyle ':completion:*' menu select # Tab goes into the list of options.
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} # Color-coded completions
zmodload zsh/complist

# only runs the full compinit once every 24hrs. uses cached compinit otherwise.
# needs EXTENDED_GLOB for (#qN.mh+24) to work.
setopt EXTENDED_GLOB
if [[ -n "${HOME}/.zcompdump"(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
_comp_options+=(globdots) # Ensure hidden files are listed in completions
zle_highlight=('paste:none') # Disable highlighting pasted text

# DIV: >>> MY CUSTOM KEYBINDS <<<

# Makes Ctrl+a accept zsh completions
bindkey '^[a' autosuggest-accept

# Edit line in vim buffer
autoload -U edit-command-line; zle -N edit-command-line
bindkey '^e' edit-command-line

# vi mode (NOT NEEDED WITH VI MODE PLUGIN)
# bindkey -v
# export KEYTIMEOUT=1

# Use vim keybinds to select stuff in the autocomplete menujk
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char

# Opens lfcd on alt+o
# lfcd () {cd "$(command lf -print-last-dir "$@")"}
function yazicd() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}
bindkey -s '^[o' 'yazicd\n'

# eza/bat in place of ls/cat, where they're installed
(( $+commands[eza] )) && alias ls="eza --icons=auto"
(( $+commands[bat] )) && alias cat="bat -pp"

[[ -o login ]] || [[ ! -r "${HOME}/.zprofile" ]] || source "${HOME}/.zprofile"

# DIV: PLUGINS

# Load powerlevel10k theme
load_plugin romkatv/powerlevel10k powerlevel10k.zsh-theme
load_plugin jeffreytse/zsh-vi-mode zsh-vi-mode.plugin.zsh
load_plugin zdharma-continuum/history-search-multi-word history-search-multi-word.plugin.zsh
_plugin_path zsh-completions src || load_plugin zsh-users/zsh-completions zsh-completions.plugin.zsh
load_plugin hlissner/zsh-autopair autopair.zsh
#load_plugin marlonrichert/zsh-autocomplete zsh-autocomplete.plugin.zsh
load_plugin zsh-users/zsh-autosuggestions zsh-autosuggestions.zsh
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_HISTORY_IGNORE="cd *|ls *|zd *|xdg-open *|nautilus *|open *"
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8,underline"
# A local fast-syntax-highlighting would download its secondary theme on first
# load; seed it from the local copy instead.
if _plugin_path fast-syntax-highlighting share/free_theme.zsh; then
  FAST_WORK_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fsh"
  [[ -e $FAST_WORK_DIR/secondary_theme.zsh ]] || { mkdir -p "$FAST_WORK_DIR" && cp $REPLY "$FAST_WORK_DIR/secondary_theme.zsh" }
fi
load_plugin zdharma-continuum/fast-syntax-highlighting fast-syntax-highlighting.plugin.zsh

# Only where conda is installed
if [[ -x /opt/miniconda3/bin/conda ]]; then
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
