#!/usr/bin/env bash
# Executed as vscode, retaining the Wolfi rootless/network/cgroup/bind contracts.
set -euo pipefail

command -v podman
command -v buildah
command -v skopeo
runtime_dir="/run/user/$(id -u)"
runtime_ready=0
for ((attempt=0; attempt<30; attempt++)); do
    if [[ -d "$runtime_dir" ]] && [[ "$(stat -c %a "$runtime_dir")" == 700 ]]; then
        runtime_ready=1
        break
    fi
    sleep 1
done
if [[ "$runtime_ready" != 1 ]]; then
    echo "Podman runtime directory was not ready after 30 attempts: $runtime_dir" >&2
    exit 1
fi
export XDG_RUNTIME_DIR="$runtime_dir"
podman_info="$(podman info --format '{{.Host.Security.Rootless}} {{.Store.GraphDriverName}} {{.Host.NetworkBackend}} {{.Host.CgroupManager}}')"
test "$podman_info" = 'true overlay netavark cgroupfs'
podman run --rm docker.io/library/alpine:3.22 sh -c 'wget -q -O- https://example.com >/dev/null'
podman run --rm --cpus 0.25 docker.io/library/alpine:3.22 true
bind_dir="$(mktemp -d)"
trap 'rm -rf "$bind_dir"' EXIT
printf 'wolfi-podman\n' > "$bind_dir/marker"
test "$(podman run --rm -v "$bind_dir:/mnt:ro" docker.io/library/alpine:3.22 cat /mnt/marker)" = wolfi-podman
buildah info >/dev/null
skopeo inspect docker://docker.io/library/alpine:3.22 >/dev/null
