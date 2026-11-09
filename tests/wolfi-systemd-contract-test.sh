#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "${ROOT_DIR}" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
legacy = json.loads((root / "src/wolfi/.devcontainer/devcontainer.json").read_text())
systemd = json.loads((root / "src/wolfi-systemd/.devcontainer/devcontainer.json").read_text())
assert "target" not in legacy["build"]
assert systemd["build"]["target"] == "wolfi-systemd"
assert (root / "src/wolfi-systemd/.devcontainer/Dockerfile").resolve() == (
    root / "src/wolfi/.devcontainer/Dockerfile").resolve()
assert systemd["containerUser"] == "root"
assert systemd["remoteUser"] == "vscode"
assert systemd["updateRemoteUserUID"] is False
assert systemd["overrideCommand"] is False
assert "--privileged" in systemd["runArgs"]
assert "--cgroupns=private" in systemd["runArgs"]
assert "--cgroupns=host" not in systemd["runArgs"]
assert systemd["remoteEnv"]["XDG_RUNTIME_DIR"] == "/run/user/1000"
assert systemd["remoteEnv"]["DBUS_SESSION_BUS_ADDRESS"] == "unix:path=/run/user/1000/bus"
assert not any("/sys/fs/cgroup" in mount or "/var/run/docker.sock" in mount
               for mount in systemd["mounts"])

dockerfile = (root / "src/wolfi/.devcontainer/Dockerfile").read_text()
stages = re.findall(r"^FROM .* AS (\S+)$", dockerfile, re.MULTILINE)
assert stages[-3:] == ["runtime", "wolfi-systemd", "final"]
metadata_labels = re.findall(r"^LABEL devcontainer\.metadata='(.+)'$", dockerfile, re.MULTILINE)
metadata = json.loads(metadata_labels[-1])
assert metadata[0]["containerUser"] == "root"
assert metadata[0]["remoteUser"] == "vscode"
assert metadata[0]["updateRemoteUserUID"] is False
assert "apk add --no-cache dbus pam systemd systemd-systemctl" in dockerfile
assert "ENTRYPOINT [\"/usr/lib/systemd/systemd\"]" in dockerfile
assert "CMD [\"--system\", \"--unit=multi-user.target\"]" in dockerfile
assert "STOPSIGNAL SIGRTMIN+3" in dockerfile

entrypoint = (root / "src/common/entrypoint.sh").read_text()
init_gate = entrypoint.index('ROR_ENTRYPOINT_INIT_ONLY:-0')
docker_feature = entrypoint.index('/usr/local/share/docker-init.sh')
assert init_gate < docker_feature
assert 'ROR_SYSTEMD_CONTAINER:-0' in entrypoint

services = root / "src/wolfi/systemd"
init_unit = (services / "ror-container-init.service").read_text()
docker_unit = (services / "ror-docker.service").read_text()
user_unit = (services / "ror-vscode-user-manager.service").read_text()
assert "ROR_ENTRYPOINT_INIT_ONLY=1" in init_unit
assert "Type=notify" in docker_unit and "--foreground" in docker_unit
assert "loginctl enable-linger vscode" in user_unit
assert "systemctl start user@1000.service" in user_unit

runtime_smoke = (root / ".github/scripts/wolfi-systemd-runtime-smoke.sh").read_text()
assert "--cgroupns=private" in runtime_smoke
assert "--cgroupns=host" not in runtime_smoke
assert "/sys/fs/cgroup" not in runtime_smoke
assert "/var/run/docker.sock" not in runtime_smoke
assert "wolfi-systemd-homebrew-smoke.sh" in runtime_smoke
print("Wolfi systemd contract tests passed")
PY
