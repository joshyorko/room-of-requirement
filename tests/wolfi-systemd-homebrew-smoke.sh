#!/usr/bin/env bash
set -euo pipefail

export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:/usr/bin:/bin"
export HOME=/home/vscode
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
case "${T3CODE_HOME:?T3CODE_HOME must be a disposable test path}" in
    /tmp/ror-wolfi-systemd-smoke-*) ;;
    *) echo "T3CODE_HOME must use the disposable smoke-test prefix" >&2; exit 2 ;;
esac
unit=sh.brew.t3code-cli-main.service
dropin_dir="${HOME}/.config/systemd/user/${unit}.d"
verify_service() {
    brew services info t3code-cli-main >/dev/null
    systemctl --user is-active --quiet "${unit}"
    service_pid="$(systemctl --user show "${unit}" --property=MainPID --value)"
    [ "${service_pid}" -gt 1 ]
    [ "$(stat -c '%u' "/proc/${service_pid}")" = 1000 ]
    service_command="$(ps -o args= -p "${service_pid}")"
    [[ "${service_command}" == *"t3 serve"* ]] || {
        echo "Unexpected Homebrew service command" >&2
        return 1
    }
    process_count="$(ps -eo args= | awk '$0 ~ /[t]3 serve/ { count += 1 } END { print count + 0 }')"
    [ "${process_count}" -eq 1 ] || {
        echo "Expected exactly one t3 serve process, found ${process_count}" >&2
        return 1
    }

    python3 - "${service_pid}" <<'PY'
import pathlib
import sys

pid = sys.argv[1]
owned = set()
for descriptor in pathlib.Path(f"/proc/{pid}/fd").iterdir():
    target = descriptor.resolve(strict=False).name
    if target.startswith("socket:[") and target.endswith("]"):
        owned.add(target[8:-1])
listeners = set()
for table in ("/proc/net/tcp", "/proc/net/tcp6"):
    lines = pathlib.Path(table).read_text().splitlines()[1:]
    listeners.update(line.split()[9] for line in lines if line.split()[3] == "0A")
if not owned.intersection(listeners):
    raise SystemExit("Homebrew t3 serve process owns no TCP listening socket")
PY
}

case "${1:?expected setup, verify, or cleanup}" in
    setup)
        mkdir -p "${T3CODE_HOME}"
        systemctl --user set-environment "T3CODE_HOME=${T3CODE_HOME}"
        brew tap joshyorko/tools
        brew install --formula joshyorko/tools/t3code-cli-main
        brew services start t3code-cli-main
        mkdir -p "${dropin_dir}"
        printf '[Service]\nEnvironment=T3CODE_HOME=%s\n' "${T3CODE_HOME}" > "${dropin_dir}/smoke.conf"
        systemctl --user daemon-reload
        systemctl --user restart "${unit}"
        verify_service
        brew services restart t3code-cli-main
        verify_service
        printf 'PASS: Homebrew service starts and restarts as vscode with a temporary T3CODE_HOME\n'
        ;;
    verify)
        verify_service
        printf 'PASS: Homebrew t3code-cli-main service survived container stop/start\n'
        ;;
    cleanup)
        brew services stop t3code-cli-main
        if systemctl --user is-active --quiet "${unit}"; then
            echo "Homebrew service remained active after stop" >&2
            exit 1
        fi
        systemctl --user unset-environment T3CODE_HOME
        rm -rf -- "${dropin_dir}"
        systemctl --user daemon-reload
        rm -rf -- "${T3CODE_HOME}"
        printf 'PASS: Homebrew service stops and temporary T3CODE_HOME is removed\n'
        ;;
    *)
        echo "expected setup, verify, or cleanup" >&2
        exit 2
        ;;
esac
