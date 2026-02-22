#!/bin/zsh
# Room of Requirement DevContainer - Zinit + Starship Configuration
# Modern, lightweight zsh setup without oh-my-zsh

# ============================================================================
# DISABLE VS CODE SHELL INTEGRATION (conflicts with Starship prompt)
# ============================================================================
# VS Code injects prompt markers that display as %{%}∙%{%} when using Starship
unset VSCODE_SHELL_INTEGRATION

# ============================================================================
# FIRST-RUN NOTICE (client-agnostic fallback)
# ============================================================================
# Some devcontainer clients do not render /usr/local/etc/vscode-dev-containers/first-run-notice.txt.
# Show it once on first interactive shell start so users always see onboarding.
if [[ -o interactive ]] && [[ -t 1 ]]; then
    ROR_NOTICE_FILE="/usr/local/etc/vscode-dev-containers/first-run-notice.txt"
    ROR_NOTICE_MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/ror/first-run-notice.shown"
    if [[ -f "$ROR_NOTICE_FILE" && ! -f "$ROR_NOTICE_MARKER" ]]; then
        command mkdir -p "$(dirname "$ROR_NOTICE_MARKER")" 2>/dev/null || true
        command cat "$ROR_NOTICE_FILE"
        command touch "$ROR_NOTICE_MARKER" 2>/dev/null || true
    fi
fi

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
# Oh-My-Zsh plugins via zinit (aliases + completions)
zinit snippet OMZP::git
zinit snippet OMZP::kubectl
zinit snippet OMZP::ansible
zinit snippet OMZP::python

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
export HISTDIR="${ZSH_HISTORY_DIR:-$HOME/.zsh_history_dir}"
export HISTFILE="${HISTDIR}/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000

# Ensure history directory/file exists; fallback if mount is unavailable/unwritable
mkdir -p "$HISTDIR" 2>/dev/null || true
touch "$HISTFILE" 2>/dev/null || true
if [[ ! -w "$HISTFILE" ]]; then
    export HISTFILE="$HOME/.zsh_history"
    touch "$HISTFILE" 2>/dev/null || true
fi

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_FCNTL_LOCK
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

# ============================================================================
# RCC COMPLETION
# ============================================================================
#compdef rcc
compdef _rcc rcc

# zsh completion for rcc                                  -*- shell-script -*-

__rcc_debug()
{
    local file="$BASH_COMP_DEBUG_FILE"
    if [[ -n ${file} ]]; then
        echo "$*" >> "${file}"
    fi
}

_rcc()
{
    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16
    local shellCompDirectiveKeepOrder=32

    local lastParam lastChar flagPrefix requestComp out directive comp lastComp noSpace keepOrder
    local -a completions

    __rcc_debug "\n========= starting completion logic =========="
    __rcc_debug "CURRENT: ${CURRENT}, words[*]: ${words[*]}"

    # The user could have moved the cursor backwards on the command-line.
    # We need to trigger completion from the $CURRENT location, so we need
    # to truncate the command-line ($words) up to the $CURRENT location.
    # (We cannot use $CURSOR as its value does not work when a command is an alias.)
    words=("${=words[1,CURRENT]}")
    __rcc_debug "Truncated words[*]: ${words[*]},"

    lastParam=${words[-1]}
    lastChar=${lastParam[-1]}
    __rcc_debug "lastParam: ${lastParam}, lastChar: ${lastChar}"

    # For zsh, when completing a flag with an = (e.g., rcc -n=<TAB>)
    # completions must be prefixed with the flag
    setopt local_options BASH_REMATCH
    if [[ "${lastParam}" =~ '-.*=' ]]; then
        # We are dealing with a flag with an =
        flagPrefix="-P ${BASH_REMATCH}"
    fi

    # Prepare the command to obtain completions
    requestComp="${words[1]} __complete ${words[2,-1]}"
    if [ "${lastChar}" = "" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go completion code.
        __rcc_debug "Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __rcc_debug "About to call: eval ${requestComp}"

    # Use eval to handle any environment variables and such
    out=$(eval ${requestComp} 2>/dev/null)
    __rcc_debug "completion output: ${out}"

    # Extract the directive integer following a : from the last line
    local lastLine
    while IFS='\n' read -r line; do
        lastLine=${line}
    done < <(printf "%s\n" "${out[@]}")
    __rcc_debug "last line: ${lastLine}"

    if [ "${lastLine[1]}" = : ]; then
        directive=${lastLine[2,-1]}
        # Remove the directive including the : and the newline
        local suffix
        (( suffix=${#lastLine}+2))
        out=${out[1,-$suffix]}
    else
        # There is no directive specified.  Leave $out as is.
        __rcc_debug "No directive found.  Setting do default"
        directive=0
    fi

    __rcc_debug "directive: ${directive}"
    __rcc_debug "completions: ${out}"
    __rcc_debug "flagPrefix: ${flagPrefix}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        __rcc_debug "Completion received error. Ignoring completions."
        return
    fi

    local activeHelpMarker="_activeHelp_ "
    local endIndex=${#activeHelpMarker}
    local startIndex=$((${#activeHelpMarker}+1))
    local hasActiveHelp=0
    while IFS='\n' read -r comp; do
        # Check if this is an activeHelp statement (i.e., prefixed with $activeHelpMarker)
        if [ "${comp[1,$endIndex]}" = "$activeHelpMarker" ];then
            __rcc_debug "ActiveHelp found: $comp"
            comp="${comp[$startIndex,-1]}"
            if [ -n "$comp" ]; then
                compadd -x "${comp}"
                __rcc_debug "ActiveHelp will need delimiter"
                hasActiveHelp=1
            fi

            continue
        fi

        if [ -n "$comp" ]; then
            # If requested, completions are returned with a description.
            # The description is preceded by a TAB character.
            # For zsh's _describe, we need to use a : instead of a TAB.
            # We first need to escape any : as part of the completion itself.
            comp=${comp//:/\\:}

            local tab="$(printf '\t')"
            comp=${comp//$tab/:}

            __rcc_debug "Adding completion: ${comp}"
            completions+=${comp}
            lastComp=$comp
        fi
    done < <(printf "%s\n" "${out[@]}")

    # Add a delimiter after the activeHelp statements, but only if:
    # - there are completions following the activeHelp statements, or
    # - file completion will be performed (so there will be choices after the activeHelp)
    if [ $hasActiveHelp -eq 1 ]; then
        if [ ${#completions} -ne 0 ] || [ $((directive & shellCompDirectiveNoFileComp)) -eq 0 ]; then
            __rcc_debug "Adding activeHelp delimiter"
            compadd -x "--"
            hasActiveHelp=0
        fi
    fi

    if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
        __rcc_debug "Activating nospace."
        noSpace="-S ''"
    fi

    if [ $((directive & shellCompDirectiveKeepOrder)) -ne 0 ]; then
        __rcc_debug "Activating keep order."
        keepOrder="-V"
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local filteringCmd
        filteringCmd='_files'
        for filter in ${completions[@]}; do
            if [ ${filter[1]} != '*' ]; then
                # zsh requires a glob pattern to do file filtering
                filter="\*.$filter"
            fi
            filteringCmd+=" -g $filter"
        done
        filteringCmd+=" ${flagPrefix}"

        __rcc_debug "File filtering command: $filteringCmd"
        _arguments '*:filename:'"$filteringCmd"
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subdir
        subdir="${completions[1]}"
        if [ -n "$subdir" ]; then
            __rcc_debug "Listing directories in $subdir"
            pushd "${subdir}" >/dev/null 2>&1
        else
            __rcc_debug "Listing directories in ."
        fi

        local result
        _arguments '*:dirname:_files -/'" ${flagPrefix}"
        result=$?
        if [ -n "$subdir" ]; then
            popd >/dev/null 2>&1
        fi
        return $result
    else
        __rcc_debug "Calling _describe"
        if eval _describe $keepOrder "completions" completions $flagPrefix $noSpace; then
            __rcc_debug "_describe found some completions"

            # Return the success of having called _describe
            return 0
        else
            __rcc_debug "_describe did not find completions."
            __rcc_debug "Checking if we should do file completion."
            if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
                __rcc_debug "deactivating file completion"

                # We must return an error code here to let zsh know that there were no
                # completions found by _describe; this is what will trigger other
                # matching algorithms to attempt to find completions.
                # For example zsh can match letters in the middle of words.
                return 1
            else
                # Perform file completion
                __rcc_debug "Activating file completion"

                # We must return the result of this command, so it must be the
                # last command, or else we must store its result to return it.
                _arguments '*:filename:_files'" ${flagPrefix}"
            fi
        fi
    fi
}

# don't run the completion function when being source-ed or eval-ed
if [ "$funcstack[1]" = "_rcc" ]; then
    _rcc
fi

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
