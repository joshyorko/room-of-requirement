#!/bin/bash
# Seed user mise cache from system installation if empty
# This enables instant startup by copying pre-installed runtimes from the Docker image
# to the user's volume-mounted cache directory

SYSTEM_DIR="/usr/local/share/mise"
USER_DIR="${HOME}/.local/share/mise"

# Only seed if system dir has installs and user dir is empty or missing
if [ -d "$SYSTEM_DIR/installs" ] && [ ! -d "$USER_DIR/installs" ]; then
    echo "[mise-seed] Copying pre-installed runtimes to user cache..."
    mkdir -p "$USER_DIR"
    cp -r "$SYSTEM_DIR/installs" "$USER_DIR/"
    cp -r "$SYSTEM_DIR/shims" "$USER_DIR/" 2>/dev/null || true
    cp -r "$SYSTEM_DIR/downloads" "$USER_DIR/" 2>/dev/null || true
    echo "[mise-seed] Done - node, python, go available immediately"
fi
