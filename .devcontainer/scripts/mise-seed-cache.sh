#!/bin/bash
# Seed user mise cache from system installation if empty
# This enables instant startup by copying pre-installed runtimes from the Docker image
# to the user's volume-mounted cache directory

SYSTEM_DIR="/usr/local/share/mise"
USER_DIR="${HOME}/.local/share/mise"
PERMISSION_ISSUE=false

# Ensure user directory exists with correct permissions
if [ ! -d "$USER_DIR" ]; then
    echo "[mise-seed] Creating mise cache directory..."
    if ! mkdir -p "$USER_DIR" 2>/dev/null; then
        echo "[mise-seed] WARNING: Cannot create $USER_DIR"
        echo "[mise-seed] This is expected in Codespaces - permissions will be fixed on container start"
        PERMISSION_ISSUE=true
    fi
fi

# Only seed if system dir has installs and user dir is empty or missing
if [ -d "$SYSTEM_DIR/installs" ] && [ ! -d "$USER_DIR/installs" ] && [ "$PERMISSION_ISSUE" = false ]; then
    echo "[mise-seed] Copying pre-installed runtimes to user cache..."
    if ! cp -r "$SYSTEM_DIR/installs" "$USER_DIR/" 2>/dev/null; then
        echo "[mise-seed] WARNING: Cannot copy installs to $USER_DIR"
        echo "[mise-seed] This is expected in Codespaces - will be fixed on container start"
    else
        # Copy shims and downloads (optional, don't fail if missing)
        if ! cp -r "$SYSTEM_DIR/shims" "$USER_DIR/" 2>/dev/null; then
            echo "[mise-seed] Note: No shims directory to copy (this is normal)"
        fi
        if ! cp -r "$SYSTEM_DIR/downloads" "$USER_DIR/" 2>/dev/null; then
            echo "[mise-seed] Note: No downloads directory to copy (this is normal)"
        fi
        echo "[mise-seed] Done - node, python, go available immediately"
    fi
elif [ "$PERMISSION_ISSUE" = true ]; then
    echo "[mise-seed] Skipping cache seeding due to permission issues - will be handled by entrypoint"
else
    echo "[mise-seed] Cache already seeded or system installation not found"
fi
