#!/bin/zsh
# Room of Requirement DevContainer - Zinit + Starship Configuration
# Modern, lightweight zsh setup without oh-my-zsh

# ============================================================================
# ZINIT PLUGIN MANAGER BOOTSTRAP
# ============================================================================
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Auto-install zinit if not present
if [[ ! -d "$ZINIT_HOME" ]]; then
    print -P "%F{blue}Installing zinit...%f"
    command mkdir -p "$(dirname $ZINIT_HOME)"
    command git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" 2>/dev/null
fi

source "${ZINIT_HOME}/zinit.zsh"

# ============================================================================
# ZINIT PLUGINS (turbo mode for fast startup)
# ============================================================================
# Autosuggestions - suggests commands as you type based on history
zinit light zsh-users/zsh-autosuggestions

# Completions - additional completion definitions
zinit light zsh-users/zsh-completions

# History substring search - up/down arrows search history
zinit light zsh-users/zsh-history-substring-search

# Syntax highlighting - must be loaded last among plugins
zinit light zsh-users/zsh-syntax-highlighting

# ============================================================================
# COMPLETION SYSTEM
# ============================================================================
autoload -Uz compinit
compinit -C

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================
export HISTFILE=~/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000

setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_SPACE

# ============================================================================
# SHELL OPTIONS
# ============================================================================
setopt EXTENDED_GLOB
setopt GLOBDOTS
setopt NO_CASE_GLOB
setopt AUTO_CD
setopt CORRECT

# ============================================================================
# KEY BINDINGS
# ============================================================================
bindkey -e  # Emacs mode
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[3~' delete-char

# ============================================================================
# PATH CONFIGURATION
# ============================================================================
export PATH="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}/bin:${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export TZ=UTC
export EDITOR=vim
export VISUAL=vim
export CLICOLOR=1
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'

# Homebrew settings
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1

# ============================================================================
# TOOL INITIALIZATION
# ============================================================================
# mise-en-place (polyglot runtime manager)
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
fi

# zoxide (smarter cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# fzf key bindings and completion
if command -v fzf &> /dev/null; then
    source <(fzf --zsh 2>/dev/null) || true
fi

# ============================================================================
# ALIASES
# ============================================================================
# Modern CLI replacements
if command -v eza &> /dev/null; then
    alias ls='eza'
    alias ll='eza -lah --icons'
    alias la='eza -la --icons'
    alias l='eza -l --icons'
    alias tree='eza --tree --icons'
else
    alias ll='ls -lah'
    alias la='ls -la'
    alias l='ls -l'
fi

command -v bat &> /dev/null && alias cat='bat --paging=never'
command -v rg &> /dev/null && alias grep='rg'
command -v fd &> /dev/null && alias find='fd'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git
alias g='git'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'
alias gst='git status'
alias gd='git diff'

# Kubernetes (if available)
if command -v kubectl &> /dev/null; then
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kgn='kubectl get nodes'
fi

# ============================================================================
# FUNCTIONS
# ============================================================================
# Create directory and cd into it
mkcd() { mkdir -p "$@" && cd "$_"; }

# Extract archives
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.tar.xz)  tar xJf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.tgz)     tar xzf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.Z)       uncompress "$1" ;;
            *.rar)     unrar x "$1" ;;
            *)         echo "Unknown archive format" ;;
        esac
    else
        echo "File not found: $1"
    fi
}

# ============================================================================
# STARSHIP PROMPT (must be last)
# ============================================================================
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
else
    # Fallback prompt
    PROMPT='%F{blue}%n@%m%f:%F{green}%~%f$ '
fi
