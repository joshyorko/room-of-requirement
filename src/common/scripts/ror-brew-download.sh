#!/usr/bin/env bash
set -euo pipefail

log() {
    echo "[ror-brew-download] $*" >&2
}

find_brewfile() {
    local brewfile="${ROR_BREWFILE:-/usr/share/ror/brew/ror.Brewfile}"

    if [ -f "$brewfile" ]; then
        printf '%s\n' "$brewfile"
        return
    fi

    if [ -f ".devcontainer/brew/ror.Brewfile" ]; then
        printf '%s\n' ".devcontainer/brew/ror.Brewfile"
        return
    fi

    if [ -f "src/common/brew/ror.Brewfile" ]; then
        printf '%s\n' "src/common/brew/ror.Brewfile"
        return
    fi

    local ws
    for ws in /workspaces/*/; do
        if [ -f "${ws}src/common/brew/ror.Brewfile" ]; then
            printf '%s\n' "${ws}src/common/brew/ror.Brewfile"
            return
        fi

        if [ -f "${ws}.devcontainer/brew/ror.Brewfile" ]; then
            printf '%s\n' "${ws}.devcontainer/brew/ror.Brewfile"
            return
        fi
    done

    return 1
}

if ! command -v brew >/dev/null 2>&1; then
    log "brew not found in PATH"
    exit 1
fi

brewfile="$(find_brewfile)" || {
    log "No RoR Brewfile found"
    exit 1
}

log "Downloading Homebrew artifacts from ${brewfile}"

while IFS= read -r line; do
    line="${line%%#*}"

    if [[ "$line" =~ ^[[:space:]]*tap[[:space:]]+\"([^\"]+)\" ]]; then
        tap="${BASH_REMATCH[1]}"
        log "Tapping ${tap}"
        brew tap "$tap"
    elif [[ "$line" =~ ^[[:space:]]*brew[[:space:]]+\"([^\"]+)\" ]]; then
        formula="${BASH_REMATCH[1]}"
        log "Fetching formula ${formula}"
        brew fetch --formula --deps "$formula"
    elif [[ "$line" =~ ^[[:space:]]*cask[[:space:]]+\"([^\"]+)\" ]]; then
        cask="${BASH_REMATCH[1]}"
        log "Fetching cask ${cask}"
        brew fetch --cask "$cask"
    fi
done < "$brewfile"

log "Done"
