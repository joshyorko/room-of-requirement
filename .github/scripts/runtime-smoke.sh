#!/usr/bin/env bash
# CI owns only this disposable container and its anonymous volumes.
set -euo pipefail

image="${1:?image required}"
variant="${2:?variant required}"
scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_root="$(cd "$scripts/../.." && pwd)"
case "$variant" in
    ubuntu-noble|debian-trixie|wolfi) ;;
    *) echo "Unsupported smoke variant: $variant" >&2; exit 1 ;;
esac

container="$(docker run -d --privileged \
    --mount type=volume,target=/var/lib/docker \
    --mount type=volume,target=/var/lib/containerd \
    --mount "type=bind,source=$source_root,target=/ror-source,readonly" \
    "$image" sleep infinity)"
cleanup() {
    docker rm -f -v "$container" >/dev/null
}
trap cleanup EXIT
docker exec -i "$container" bash --noprofile --norc -s < "$scripts/docker-smoke.sh"
if [[ "$variant" == wolfi ]]; then
    docker exec -i --user vscode "$container" bash --noprofile --norc -s < "$scripts/podman-smoke.sh"
fi
docker exec --user root "$container" bash /ror-source/.github/scripts/home-smoke.sh
docker exec -t --user root -e TERM=xterm-ghostty "$container" \
    bash /ror-source/.github/scripts/ghostty-smoke.sh root
docker exec -t --user vscode -e TERM=xterm-ghostty "$container" \
    bash /ror-source/.github/scripts/ghostty-smoke.sh vscode
if [[ "$variant" == wolfi ]]; then
    docker exec --user root "$container" bash /ror-source/tests/runtime-native-smoke.sh --in-container
    bash "$source_root/tests/runtime-docker-image-smoke.sh" "$image"
fi
