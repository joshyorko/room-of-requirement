#!/usr/bin/env bash
# Executed inside the candidate; daemon startup remains owned by the image.
set -euo pipefail

command -v docker
command -v dockerd
for ((attempt=0; attempt<30; attempt++)); do
    if docker info >/dev/null 2>&1; then
        docker info --format 'driver={{.Driver}} root={{.DockerRootDir}}'
        docker version
        docker run --rm hello-world
        exit 0
    fi
    sleep 1
done
docker version || true
if [[ -f /tmp/dockerd.log ]]; then
    tail -200 /tmp/dockerd.log
fi
echo 'Docker API was not ready after 30 attempts' >&2
exit 1
