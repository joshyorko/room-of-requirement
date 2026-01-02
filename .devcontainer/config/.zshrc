#!/bin/zsh
# Default ZSH configuration for Room of Requirement DevContainer
# T015: Create default .zshrc with Starship/mise/zoxide initialization

# ============================================================================
# HISTORY CONFIGURATION (T078)
# ============================================================================
export HISTFILE=~/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000

# History options
setopt INC_APPEND_HISTORY           # Add commands to history immediately
setopt SHARE_HISTORY                # Share history between sessions
setopt HIST_IGNORE_DUPS             # Don't record duplicate commands
setopt HIST_IGNORE_ALL_DUPS         # Remove older duplicate entries
setopt HIST_FIND_NO_DUPS            # Don't show duplicate entries in search
setopt HIST_EXPIRE_DUPS_FIRST       # Remove duplicates when history is full

# ============================================================================
# COMPLETION & EXPANSION
# ============================================================================
setopt EXTENDED_GLOB
setopt GLOBDOTS
setopt NO_CASE_GLOB

# ============================================================================
# KEY BINDINGS (T080 - Ctrl+R history search)
# ============================================================================
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search

# ============================================================================
# TOOL INITIALIZATION (T031, T036, T079)
# ============================================================================

# mise-en-place activation (T036 - polyglot tool manager for interactive shells)
if command -v mise &> /dev/null; then
    # Activate mise for the current shell session
    eval "$(mise activate zsh)"
    # Enable environment variable loading from .mise.toml files
    eval "$(mise hook-env -s zsh)"
fi

# zoxide initialization (T079 - directory navigation with z alias)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
    alias z='__zoxide_z'
    alias zi='__zoxide_zi'
fi

# Starship prompt (T075 - modern shell prompt)
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# ============================================================================
# PATH CONFIGURATION (T031)
# ============================================================================
# Precedence: mise shims > Homebrew > /usr/local/bin > standard paths
export PATH="/usr/local/share/mise/shims:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export TZ=UTC
export EDITOR=vim
export VISUAL=vim

# Homebrew settings
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1

# ============================================================================
# COMMON ALIASES
# ============================================================================
# Modern CLI tool aliases (use if installed via Homebrew)
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

if command -v bat &> /dev/null; then
    alias cat='bat --paging=never'
    alias less='bat'
fi

if command -v rg &> /dev/null; then
    alias grep='rg'
fi

if command -v fd &> /dev/null; then
    alias find='fd'
fi

alias ..='cd ..'
alias ...='cd ../..'
alias clear='clear && echo "Welcome to Room of Requirement"'

# Git aliases
alias g='git'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'
alias gst='git status'
alias gd='git diff'

# Kubernetes aliases (if kubectl installed)
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
mkcd() {
    mkdir -p "$@" && cd "$_"
}

# Extract archive
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"   ;;
            *.tar.gz)    tar xzf "$1"   ;;
            *.tar.xz)    tar xJf "$1"   ;;
            *.bz2)       bunzip2 "$1"   ;;
            *.rar)       unrar x "$1"   ;;
            *.gz)        gunzip "$1"    ;;
            *.tar)       tar xf "$1"    ;;
            *.tgz)       tar xzf "$1"   ;;
            *.zip)       unzip "$1"     ;;
            *.Z)         uncompress "$1";;
            *)           echo "Unknown file type" ;;
        esac
    else
        echo "File not found"
    fi
}

# ============================================================================
# PROMPT CUSTOMIZATION (fallback if Starship not available)
# ============================================================================
if ! command -v starship &> /dev/null; then
    PROMPT='%F{blue}%n@%m%f:%F{green}%~%f$ '
fi

# ============================================================================
# PLUGIN LOADING (from Homebrew)
# ============================================================================
# Load zsh-autosuggestions from Homebrew
if [ -f "${HOMEBREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "${HOMEBREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Load zsh-syntax-highlighting from Homebrew (must be loaded last)
if [ -f "${HOMEBREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "${HOMEBREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Load fzf key bindings if installed
if [ -f "${HOMEBREW_PREFIX}/opt/fzf/shell/key-bindings.zsh" ]; then
    source "${HOMEBREW_PREFIX}/opt/fzf/shell/key-bindings.zsh"
fi

# ============================================================================
# COLOR SUPPORT
# ============================================================================
export CLICOLOR=1
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
