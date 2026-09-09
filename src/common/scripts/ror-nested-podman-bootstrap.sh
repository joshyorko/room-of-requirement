#!/usr/bin/env bash
# Opt-in startup for a new, nonprivileged Kubernetes Room container. Never run
# against an existing workspace or a host/shared cgroup namespace.
set -euo pipefail

die() {
    printf 'ERROR: nested Podman bootstrap: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" == 0 ]] || die 'must run as root at container startup'
[[ "$(cat /proc/self/cgroup)" == '0::/' ]] ||
    die 'requires a private cgroup namespace rooted at this container'
[[ "$(cat /proc/1/cgroup)" == '0::/' ]] ||
    die 'must run before starting other processes or moving PID 1'
[[ "$(stat -f -c %T /sys/fs/cgroup)" == cgroup2fs ]] || die 'requires cgroup v2'

# The global hierarchy root has no resource-limit files. Together with the
# namespace-relative / membership, these guards reject the host hierarchy and
# privileged Kubernetes launches before mounting or changing ownership.
[[ -f /sys/fs/cgroup/cpu.max && -f /sys/fs/cgroup/memory.max ]] ||
    die 'refusing the global cgroup root; container resource boundaries are missing'
[[ ! -e /sys/fs/cgroup/room-init ]] || die 'container cgroup is already initialized'
vscode_uid="$(id -u vscode)"
vscode_gid="$(id -g vscode)"
[[ "$vscode_uid" != 0 ]] || die 'vscode must be a non-root user'
read -r -a controllers < /sys/fs/cgroup/cgroup.controllers
[[ ${#controllers[@]} -gt 0 ]] || die 'no controllers delegated by the outer runtime'
for required in cpu cpuset io memory pids; do
    [[ " ${controllers[*]} " == *" $required "* ]] || die "missing controller: $required"
done
[[ ! -L /dev/net && ! -L /dev/net/tun ]] || die 'refusing symlinked TUN device paths'
if [[ -e /dev/net/tun ]]; then
    [[ -c /dev/net/tun && "$(stat -c '%t:%T' /dev/net/tun)" == a:c8 ]] ||
        die 'existing /dev/net/tun is not device 10:200'
fi

# A new mount is rooted at this cgroup namespace. Merely requesting a private
# namespace for nested Podman leaves runsc traversing the old visible root.
# Do not remount the host superblock or bind a host cgroup path here.
mount -t cgroup2 -o rw,nosuid,nodev,noexec cgroup2 /sys/fs/cgroup
mkdir /sys/fs/cgroup/room-init

# cgroup v2 forbids internal processes when domain controllers are enabled.
# Snapshot only this container's root PIDs; new children inherit room-init.
mapfile -t container_pids < /sys/fs/cgroup/cgroup.procs
for pid in "${container_pids[@]}"; do
    if ! { printf '%s\n' "$pid" > /sys/fs/cgroup/room-init/cgroup.procs; } 2>/dev/null; then
        kill -0 "$pid" 2>/dev/null && die "could not move container PID $pid"
    fi
done
for controller in "${controllers[@]}"; do
    printf '+%s\n' "$controller" > /sys/fs/cgroup/cgroup.subtree_control
done

# Delegate management, not outer limits: never recursively chown or change
# cpu.max, memory.max, pids.max, ancestors, or sibling container cgroups.
chown "$vscode_uid:$vscode_gid" \
    /sys/fs/cgroup \
    /sys/fs/cgroup/cgroup.procs \
    /sys/fs/cgroup/cgroup.threads \
    /sys/fs/cgroup/cgroup.subtree_control

# pasta needs the TUN node even with a user-owned network namespace. The OCI
# device policy must already permit 10:200; this never changes that policy.
if [[ ! -e /dev/net/tun ]]; then
    mkdir -p /dev/net
    mknod -m 0666 /dev/net/tun c 10 200
fi
printf 'Nested Podman cgroup delegation prepared for uid %s; runtime acceptance requires the runsc probe.\n' "$vscode_uid"
