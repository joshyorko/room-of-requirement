#!/bin/bash
# Fix cgroup v2 memory controller delegation for k3d/k3s
#
# This script implements a workaround for environments like GitHub Codespaces
# where the root cgroup doesn't delegate memory controller to subtree_control.
#
# Strategy:
# 1. Move all processes from root cgroup to a new /init.scope cgroup
# 2. Enable memory controller delegation in root cgroup's subtree_control
# 3. This allows Docker containers (and k3s within them) to get memory delegation
#
# References:
# - https://github.com/k3s-io/k3s/issues/6879#issuecomment-1665488405
# - https://github.com/k3d-io/k3d/issues/1268
# - https://systemd.io/CGROUP_DELEGATION/

set -e

log() {
    echo "[cgroup-fix] $*" >&2
}

# Check if we're on cgroup v2
if [ ! -f /sys/fs/cgroup/cgroup.controllers ]; then
    log "Not on cgroup v2 - skipping"
    exit 0
fi

# Check if memory controller is available
AVAILABLE_CONTROLLERS=$(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null || echo "")
if ! echo "$AVAILABLE_CONTROLLERS" | grep -q "memory"; then
    log "Memory controller not available at root"
    exit 0
fi

log "cgroup v2 detected with memory controller available"

# Check if memory is already delegated
SUBTREE_CONTROL=$(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || echo "")
if echo "$SUBTREE_CONTROL" | grep -q "memory"; then
    log "✓ Memory controller already delegated"
    exit 0
fi

log "Memory controller NOT delegated - applying workaround..."

# Strategy 1: Move processes to init.scope and enable delegation
# This is the k3d recommended approach for rootful containers
if [ -w /sys/fs/cgroup/cgroup.subtree_control ]; then
    log "Attempting process evacuation to /sys/fs/cgroup/init.scope..."

    # Create init.scope if it doesn't exist
    if [ ! -d /sys/fs/cgroup/init.scope ]; then
        mkdir -p /sys/fs/cgroup/init.scope 2>/dev/null || true
    fi

    # Move all processes from root cgroup to init.scope
    if [ -d /sys/fs/cgroup/init.scope ]; then
        # Read all PIDs from root cgroup
        PIDS=$(cat /sys/fs/cgroup/cgroup.procs 2>/dev/null || echo "")

        for pid in $PIDS; do
            # Skip if PID is empty or invalid
            [ -z "$pid" ] && continue
            [ "$pid" = "$$" ] && continue  # Don't move ourselves

            # Try to move process to init.scope
            echo "$pid" > /sys/fs/cgroup/init.scope/cgroup.procs 2>/dev/null || true
        done

        log "Moved processes to init.scope"

        # Now try to enable memory delegation in root subtree_control
        if echo "+memory" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null; then
            log "✓ Successfully enabled memory controller delegation"
            exit 0
        else
            log "⚠ Failed to enable memory delegation after process evacuation"
        fi
    else
        log "⚠ Could not create init.scope directory"
    fi
else
    log "⚠ No write access to /sys/fs/cgroup/cgroup.subtree_control"
fi

# Strategy 2: Use systemd-run to create a delegated scope
# This works when systemd is available
if command -v systemd-run >/dev/null 2>&1; then
    log "Attempting systemd-run delegation workaround..."

    # Check if we have a systemd connection
    if systemctl status >/dev/null 2>&1; then
        # Create a transient scope with delegation
        # This requires systemd to be running
        log "systemd detected - delegation may be possible via systemd-run"
        log "Note: k3d/k3s should be started with: systemd-run --scope -p Delegate=yes <command>"
        exit 0
    else
        log "systemd not active (no system bus connection)"
    fi
fi

# Strategy 3: Document that Docker daemon needs special flags
log ""
log "=== Workaround Instructions ==="
log ""
log "To make k3d/k3s work in this environment, you need to:"
log ""
log "1. Ensure Docker is using the Codespaces host socket (not DinD)"
log "   This is automatically done when ROR_DOCKER_BACKEND=auto (default)"
log ""
log "2. Create k3d clusters with these flags:"
log "   export K3D_FIX_CGROUPV2=1"
log "   k3d cluster create mycluster \\"
log "     --volume /sys/fs/cgroup:/sys/fs/cgroup:rw \\"
log "     --k3s-arg '--kubelet-arg=feature-gates=KubeletInUserNamespace=true@server:*'"
log ""
log "3. Alternative: Use Kind instead of k3d (better Codespaces support)"
log "   kind create cluster"
log ""
log "4. If still failing, check: ujust cgroup-check"
log ""

exit 0
