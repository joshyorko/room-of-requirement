#!/usr/bin/env bash
set -euo pipefail

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[ "$(cat /proc/1/comm)" = systemd ] || fail "PID 1 is not systemd"
[[ "$(readlink /proc/1/exe)" == */systemd ]] || fail "/proc/1/exe is not systemd"
awk '$5 == "/sys/fs/cgroup" && $0 ~ / - cgroup2 / { found = 1 } END { exit !found }' \
    /proc/1/mountinfo || fail "systemd cgroup v2 mount is missing"
grep -q '^0::' /proc/1/cgroup || fail "unified cgroup v2 hierarchy is missing"

state="$(systemctl is-system-running 2>&1 || true)"
[ "${state}" = running ] || {
    systemctl --failed --no-pager >&2 || true
    fail "system manager is ${state}; expected running"
}
systemctl is-active --quiet ror-container-init.service || fail "RoR initialization unit is inactive"
systemctl is-active --quiet ror-docker.service || fail "RoR Docker service is inactive"
systemctl is-active --quiet user@1000.service || fail "vscode user manager is inactive"
systemctl show user@1000.service --property=ControlGroup --value | grep -q . || \
    fail "vscode manager has no systemd service cgroup"
loginctl show-user vscode --property=Linger --value | grep -qx yes || \
    fail "vscode lingering is not enabled"
[ -S /run/user/1000/bus ] || fail "vscode user D-Bus socket is missing"

printf 'PASS: PID 1 is systemd; unified cgroup-v2 manager and logind services are active\n'
