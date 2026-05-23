#!/bin/bash
# Enable cgroup v2 memory controller delegation for k3d/k3s in GitHub Codespaces
#
# Problem: GitHub Codespaces runs on Azure VMs with cgroup v2, but the outer
# orchestrator only delegates 'cpuset cpu pids' to subtree_control - NOT 'memory'.
# This causes k3s (used by k3d) to crash with "Error: failed to find memory cgroup (v2)".
#
# Solution: Walk the cgroup tree and enable memory controller delegation where
# possible before starting dockerd.
#
# References:
# - https://github.com/kubernetes/kubernetes/issues/106331
# - https://github.com/k3s-io/k3s/issues/6879

set -e

log() {
    echo "[cgroup-memory] $*" >&2
}

# Check if we're on cgroup v2 (unified hierarchy)
if [ ! -f /sys/fs/cgroup/cgroup.controllers ]; then
    log "Not on cgroup v2 - skipping memory controller delegation"
    exit 0
fi

# Check if memory controller is available at root
AVAILABLE_CONTROLLERS=$(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null || echo "")
if ! echo "$AVAILABLE_CONTROLLERS" | grep -q "memory"; then
    log "Warning: memory controller not available at cgroup root"
    log "Available controllers: $AVAILABLE_CONTROLLERS"
    exit 0
fi

log "cgroup v2 detected with memory controller available"

# Function to enable memory controller in a cgroup
enable_memory_in_cgroup() {
    local cgroup_path="$1"
    local subtree_control="${cgroup_path}/cgroup.subtree_control"

    # Check if we can write to this cgroup
    if [ ! -w "$subtree_control" ]; then
        return 1
    fi

    # Check if memory is already enabled
    local current=$(cat "$subtree_control" 2>/dev/null || echo "")
    if echo "$current" | grep -q "memory"; then
        return 0  # Already enabled
    fi

    # Try to enable memory controller
    if echo "+memory" > "$subtree_control" 2>/dev/null; then
        log "✓ Enabled memory controller in $cgroup_path"
        return 0
    else
        return 1
    fi
}

# Try to enable memory delegation at root level
log "Attempting to enable memory controller delegation..."

# First, try the root cgroup
if enable_memory_in_cgroup "/sys/fs/cgroup"; then
    log "✓ Memory controller enabled at root cgroup"
else
    log "⚠ Could not enable memory controller at root cgroup (insufficient permissions)"
    log "This is expected in GitHub Codespaces - memory controller delegation is restricted"
fi

# Walk the cgroup tree and try to enable memory in any writable descendant cgroups
# This helps when running in a nested container where we might have control over
# sub-cgroups even if we don't control the root
CURRENT_CGROUP=$(cat /proc/self/cgroup 2>/dev/null | cut -d: -f3 || echo "/")
if [ "$CURRENT_CGROUP" != "/" ] && [ "$CURRENT_CGROUP" != "" ]; then
    CURRENT_CGROUP_PATH="/sys/fs/cgroup${CURRENT_CGROUP}"
    if [ -d "$CURRENT_CGROUP_PATH" ]; then
        log "Current cgroup: $CURRENT_CGROUP_PATH"
        if enable_memory_in_cgroup "$CURRENT_CGROUP_PATH"; then
            log "✓ Memory controller enabled in current cgroup"
        fi
    fi
fi

# Check final state and provide diagnostic info
log "Final cgroup state:"
log "  Root controllers: $(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null || echo 'unknown')"
log "  Root subtree_control: $(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || echo 'unknown')"

if [ "$CURRENT_CGROUP" != "/" ] && [ "$CURRENT_CGROUP" != "" ]; then
    CURRENT_CGROUP_PATH="/sys/fs/cgroup${CURRENT_CGROUP}"
    if [ -d "$CURRENT_CGROUP_PATH" ]; then
        log "  Current cgroup controllers: $(cat ${CURRENT_CGROUP_PATH}/cgroup.controllers 2>/dev/null || echo 'unknown')"
    fi
fi

# Detect if memory controller will be available to containers started by dockerd
# by checking if it's in the subtree_control of our current cgroup
SUBTREE_CONTROL=$(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || echo "")
if echo "$SUBTREE_CONTROL" | grep -q "memory"; then
    log "✓ Memory controller will be available to Docker containers"
    log "✓ k3d/k3s should work correctly"
    exit 0
else
    log "⚠ WARNING: Memory controller NOT delegated to child cgroups"
    log "⚠ k3d/k3s will fail with 'Error: failed to find memory cgroup (v2)'"
    log ""
    log "This is a known limitation of GitHub Codespaces infrastructure."
    log "The Codespaces orchestrator restricts cgroup controller delegation for resource isolation."
    log ""
    log "Workarounds:"
    log "  1. Use Docker Desktop locally (full cgroup delegation)"
    log "  2. Use DevPod on k3s/k8s (proper cgroup delegation)"
    log "  3. Request GitHub Codespaces team to enable memory controller delegation"
    log ""
    log "To detect this issue early, you can run:"
    log "  cat /sys/fs/cgroup/cgroup.subtree_control"
    log ""
    exit 0  # Don't fail - just warn (allow container to start for other work)
fi
