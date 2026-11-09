#!/usr/bin/env bash
set -euo pipefail

unit=ror-systemd-smoke.service
unit_file="${HOME}/.config/systemd/user/${unit}"

systemctl --user show-environment >/dev/null
systemctl --user is-active --quiet default.target

case "${1:?expected setup, verify, or cleanup}" in
    setup)
        mkdir -p "$(dirname "${unit_file}")"
        cat > "${unit_file}" <<'UNIT'
[Unit]
Description=Disposable systemd user-manager smoke service

[Service]
Type=simple
ExecStart=/usr/bin/sleep infinity

[Install]
WantedBy=default.target
UNIT
        systemctl --user daemon-reload
        systemctl --user enable --now "${unit}"
        systemctl --user restart "${unit}"
        ;;
    verify)
        systemctl --user is-active --quiet "${unit}"
        ;;
    cleanup)
        systemctl --user disable --now "${unit}" || true
        if systemctl --user is-active --quiet "${unit}"; then
            echo "Disposable user service remained active after stop" >&2
            exit 1
        fi
        rm -f "${unit_file}"
        systemctl --user daemon-reload
        exit 0
        ;;
    *)
        echo "expected setup, verify, or cleanup" >&2
        exit 2
        ;;
esac

pid="$(systemctl --user show "${unit}" --property=MainPID --value)"
[ "${pid}" -gt 1 ]
[ "$(stat -c '%u' "/proc/${pid}")" = 1000 ]
printf 'PASS: persistent vscode user service is active as UID 1000\n'
