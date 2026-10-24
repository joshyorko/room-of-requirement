#!/usr/bin/env bash
set -euo pipefail

# Devsy SSH sessions resolve supplementary groups from the account database.
# Docker --group-add alone does not populate that database. Never change the
# passed-through device's mode or owner: that would also modify the host device.
[ -c /dev/kvm ] || exit 0
id vscode >/dev/null 2>&1 || exit 0
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -n /bin/bash "$0"
fi

gid="$(stat -c '%g' /dev/kvm)"
if [ "${gid}" = 0 ]; then
    echo '[KVM] Warning: /dev/kvm belongs to group 0; configure a dedicated KVM group on the host rather than granting vscode the root group.' >&2
    exit 0
fi
if record="$(getent group "${gid}")"; then
    group="${record%%:*}"
else
    group="ror-kvm-${gid}"
    groupadd -g "${gid}" "${group}"
fi
usermod -aG "${group}" vscode
