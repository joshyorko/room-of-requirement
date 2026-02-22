#!/bin/bash
# Room of Requirement DevContainer - Bash Configuration
# Starship prompt shared with zsh via starship.toml

# ============================================================================
# PATH CONFIGURATION
# ============================================================================
export PATH="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}/bin:${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# ============================================================================
# FIRST-RUN NOTICE (client-agnostic fallback)
# ============================================================================
# Some devcontainer clients do not render /usr/local/etc/vscode-dev-containers/first-run-notice.txt.
# Show it once on first interactive shell start so users always see onboarding.
if [[ $- == *i* ]] && [ -t 1 ]; then
    ROR_NOTICE_FILE="/usr/local/etc/vscode-dev-containers/first-run-notice.txt"
    ROR_NOTICE_MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/ror/first-run-notice.shown"
    if [ -f "$ROR_NOTICE_FILE" ] && [ ! -f "$ROR_NOTICE_MARKER" ]; then
        mkdir -p "$(dirname "$ROR_NOTICE_MARKER")" 2>/dev/null || true
        command cat "$ROR_NOTICE_FILE"
        touch "$ROR_NOTICE_MARKER" 2>/dev/null || true
    fi
fi

# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export TZ=UTC
export EDITOR=vim
export VISUAL=vim
export CLICOLOR=1

# Homebrew settings
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1

# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================
export HISTFILE=~/.bash_history
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# ============================================================================
# SHELL OPTIONS
# ============================================================================
shopt -s checkwinsize
shopt -s globstar 2>/dev/null
shopt -s cdspell

# ============================================================================
# TOOL INITIALIZATION
# ============================================================================
# mise-en-place (polyglot runtime manager)
if command -v mise &> /dev/null; then
    eval "$(mise activate bash)"
fi

# zoxide (smarter cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

# fzf key bindings and completion
if command -v fzf &> /dev/null; then
    eval "$(fzf --bash 2>/dev/null)" || true
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
# STARSHIP PROMPT (must be last)
# ============================================================================
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi
