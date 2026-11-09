#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="$(mktemp -d /tmp/wolfi-systemd-init-test.XXXXXX)"
trap 'rm -rf -- "${SCRATCH}"' EXIT

for helper in /usr/local/bin/prepare-kvm.sh /usr/local/share/docker-init.sh \
    /usr/local/bin/ror-docker-start.sh; do
    if [ -x "${helper}" ]; then
        echo "Cannot safely run the entrypoint test while host helper exists: ${helper}" >&2
        exit 2
    fi
done

mkdir -p "${SCRATCH}/bin"
cat > "${SCRATCH}/bin/id" <<'SH'
#!/bin/sh
case "${1:-}" in
    -u) echo 0 ;;
    vscode) exit 0 ;;
    *) exit 1 ;;
esac
SH
cat > "${SCRATCH}/bin/getent" <<'SH'
#!/bin/sh
if [ "${1:-}" = group ] && [ "${2:-}" = docker ]; then
    echo 'docker:x:999:vscode'
    exit 0
fi
exit 1
SH
cat > "${SCRATCH}/bin/usermod" <<'SH'
#!/bin/sh
exit 0
SH
cat > "${SCRATCH}/failed-seeder" <<'SH'
#!/bin/sh
exit 23
SH
chmod +x "${SCRATCH}/bin/id" "${SCRATCH}/bin/getent" \
    "${SCRATCH}/bin/usermod" "${SCRATCH}/failed-seeder"

# Run the real entrypoint, redirecting only the external home seeder.
python3 - "${ROOT_DIR}/src/common/entrypoint.sh" "${SCRATCH}/failed-seeder" \
    "${SCRATCH}/entrypoint.sh" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()
source = source.replace("/usr/local/bin/seed-vscode-home.sh", sys.argv[2])
if "/usr/local/bin/seed-vscode-home.sh" in source:
    raise SystemExit("entrypoint seeder path replacement was incomplete")
pathlib.Path(sys.argv[3]).write_text(source)
PY
chmod +x "${SCRATCH}/entrypoint.sh"

run_mode() {
    local systemd_mode="$1"
    local expected_status="$2"
    local output="${SCRATCH}/mode-${systemd_mode}.log"
    local status

    if PATH="${SCRATCH}/bin" HOME="${SCRATCH}/home" \
        ROR_SYSTEMD_CONTAINER="${systemd_mode}" ROR_ENTRYPOINT_INIT_ONLY=1 \
        /bin/bash "${SCRATCH}/entrypoint.sh" true >"${output}" 2>&1; then
        status=0
    else
        status=$?
    fi
    if [ "${status}" -ne "${expected_status}" ]; then
        cat "${output}" >&2
        echo "Expected mode ${systemd_mode} status ${expected_status}; got ${status}" >&2
        return 1
    fi
    grep -Fq 'Warning: Failed to prepare the standard vscode home' "${output}"
}

# Systemd initialization must fail if persistent HOME cannot be prepared.
run_mode 1 1
# The existing non-systemd warning-and-continue contract remains unchanged.
run_mode 0 0
echo "Wolfi systemd init failure contract tests passed"
