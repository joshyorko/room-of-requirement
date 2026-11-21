#!/usr/bin/env bash
set -euo pipefail

export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:/usr/bin:/bin"
export HOME=/home/vscode
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
unit=sh.brew.redis.service
verify_service() {
    brew services info redis >/dev/null
    systemctl --user is-active --quiet "${unit}"
    service_pid="$(systemctl --user show "${unit}" --property=MainPID --value)"
    [ "${service_pid}" -gt 1 ]
    [ "$(stat -c '%u' "/proc/${service_pid}")" = 1000 ]
    expected_executable="$(readlink -f "$(brew --prefix redis)/bin/redis-server")"
    [ "$(readlink -f "/proc/${service_pid}/exe")" = "${expected_executable}" ] || {
        echo "Homebrew main PID is not the installed Redis server" >&2
        return 1
    }

    if ! python3 - "${service_pid}" <<'PY'
import pathlib
import sys
import time

pid = sys.argv[1]
deadline = time.monotonic() + 30
while True:
    if not pathlib.Path(f"/proc/{pid}").exists():
        raise SystemExit("Homebrew Redis process exited before listener readiness")
    owned = set()
    try:
        for descriptor in pathlib.Path(f"/proc/{pid}/fd").iterdir():
            target = descriptor.resolve(strict=False).name
            if target.startswith("socket:[") and target.endswith("]"):
                owned.add(target[8:-1])
    except FileNotFoundError:
        # A descriptor can close while procfs is being read. Retry only while
        # the original process still exists; never accept another process.
        owned.clear()
    listeners = set()
    for table in ("/proc/net/tcp", "/proc/net/tcp6"):
        lines = pathlib.Path(table).read_text().splitlines()[1:]
        listeners.update(line.split()[9] for line in lines if line.split()[3] == "0A")
    if owned.intersection(listeners):
        break
    if time.monotonic() >= deadline:
        raise SystemExit("Homebrew Redis process owns no TCP listening socket after 30 seconds")
    time.sleep(0.25)
PY
    then
        systemctl --user show "${unit}" \
            --property=ActiveState,SubState,Result,MainPID,ExecMainStatus,NRestarts >&2 || true
        return 1
    fi
}

case "${1:?expected setup, verify, or cleanup}" in
    setup)
        brew install --formula redis
        brew services start redis
        verify_service
        brew services restart redis
        verify_service
        printf 'PASS: Homebrew Redis service starts and restarts as vscode\n'
        ;;
    verify)
        verify_service
        printf 'PASS: Homebrew Redis service survived container stop/start\n'
        ;;
    cleanup)
        brew services stop redis
        if systemctl --user is-active --quiet "${unit}"; then
            echo "Homebrew service remained active after stop" >&2
            exit 1
        fi
        printf 'PASS: Homebrew Redis service stops\n'
        ;;
    *)
        echo "expected setup, verify, or cleanup" >&2
        exit 2
        ;;
esac
