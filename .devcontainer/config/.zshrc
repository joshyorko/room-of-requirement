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
# Use persistent volume directory for history (volume mounts as directory, not file)
export HISTFILE=~/.zsh_history_dir/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000

# Ensure history directory exists
[[ -d ~/.zsh_history_dir ]] && touch "$HISTFILE" 2>/dev/null || true

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
edir() {
    local editor_option=$1

    # Check if tools are in PATH first
    local needs_fzf=0
    local needs_fd=0

    # Check for fzf in PATH
    if ! command -v fzf >/dev/null 2>&1; then
        needs_fzf=1
    fi

    # Check for fd/fdfind in PATH
    if ! (command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1); then
        needs_fd=1
    fi

    # Install only if needed
    if [ $needs_fzf -eq 1 ]; then
        echo "❌ 'fzf' is not installed. Installing..."
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y fzf
        elif command -v brew >/dev/null 2>&1; then
            brew install fzf
        elif command -v cargo >/dev/null 2>&1; then
            cargo install fzf
        else
            echo "⚠️ Unable to install 'fzf'. Please install it manually."
            return 1
        fi
    fi

    if [ $needs_fd -eq 1 ]; then
        echo "❌ 'fd' is not installed. Installing..."
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y fd-find
            # Link fdfind to fd only if fd doesn't exist
            if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
                mkdir -p ~/.local/bin
                ln -s $(which fdfind) ~/.local/bin/fd
                export PATH="$HOME/.local/bin:$PATH"
                echo "Linked 'fdfind' to 'fd'."
            fi
        elif command -v brew >/dev/null 2>&1; then
            brew install fd
        elif command -v cargo >/dev/null 2>&1; then
            cargo install fd-find
        else
            echo "⚠️ Unable to install 'fd'. Please install it manually."
            return 1
        fi
    fi

    # Use fd or fdfind (whichever is available)
    local fd_cmd
    if command -v fd >/dev/null 2>&1; then
        fd_cmd="fd"
    else
        fd_cmd="fdfind"
    fi

    # Use fd to search directories
    local selected_dir
    selected_dir=$(
        { $fd_cmd . --type d "$PWD" 2>/dev/null; $fd_cmd . --type d /home 2>/dev/null; $fd_cmd . --type d /workspaces 2>/dev/null; } |
        fzf --prompt="Select a directory: "
    )

    # Check if a directory was selected
    if [ -n "$selected_dir" ]; then
        case $editor_option in
            -c)
                if command -v code >/dev/null 2>&1; then
                    code "$selected_dir"
                else
                    echo "❌ 'code' is not installed."
                    return 1
                fi
                ;;
            -n) nvim "$selected_dir" ;;  # Open in nvim if -n option is provided
            *) cd "$selected_dir" ;;     # Default behavior: change to the selected directory
        esac
    else
        echo "🚫 No directory selected."
    fi
}

# Enable Bedrock integration
#export CLAUDE_CODE_USE_BEDROCK=1
#export AWS_REGION=us-east-1  # or your preferred region


# ============================================================================
# STARSHIP PROMPT (must be last)
# ============================================================================
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
else
    # Fallback prompt
    PROMPT='%F{blue}%n@%m%f:%F{green}%~%f$ '
fi
