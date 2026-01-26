#!/bin/bash
# Seed user mise cache from system installation if empty
# This enables instant startup by copying pre-installed runtimes from the Docker image
# to the user's volume-mounted cache directory

SYSTEM_DIR="/usr/local/share/mise"
USER_DIR="${HOME}/.local/share/mise"

# Ensure user directory exists with correct permissions
if [ ! -d "$USER_DIR" ]; then
    echo "[mise-seed] Creating mise cache directory..."
    if ! mkdir -p "$USER_DIR" 2>/dev/null; then
        echo "[mise-seed] WARNING: Cannot create $USER_DIR"
        echo "[mise-seed] This is expected in Codespaces - permissions will be fixed on container start"
        exit 0
    fi
fi

# Only seed if system dir has installs and user dir is empty or missing
if [ -d "$SYSTEM_DIR/installs" ] && [ ! -d "$USER_DIR/installs" ]; then
    echo "[mise-seed] Copying pre-installed runtimes to user cache..."
    if ! cp -r "$SYSTEM_DIR/installs" "$USER_DIR/" 2>/dev/null; then
        echo "[mise-seed] WARNING: Cannot copy installs to $USER_DIR"
        echo "[mise-seed] This is expected in Codespaces - will be fixed on container start"
        exit 0
    fi
    cp -r "$SYSTEM_DIR/shims" "$USER_DIR/" 2>/dev/null || true
    cp -r "$SYSTEM_DIR/downloads" "$USER_DIR/" 2>/dev/null || true
    echo "[mise-seed] Done - node, python, go available immediately"
else
    echo "[mise-seed] Cache already seeded or system installation not found"
fi
