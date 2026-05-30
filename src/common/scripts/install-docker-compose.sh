#!/usr/bin/env bash
set -euo pipefail

compose_version="${DOCKER_COMPOSE_VERSION:-v5.1.4}"
case "${compose_version}" in
    v*) ;;
    *) compose_version="v${compose_version}" ;;
esac

input_arch="${TARGETARCH:-$(uname -m)}"
case "${input_arch}" in
    amd64|x86_64) compose_arch="x86_64" ;;
    arm64|aarch64) compose_arch="aarch64" ;;
    *)
        echo "Unsupported Docker Compose architecture: ${input_arch}" >&2
        exit 1
        ;;
esac

asset="docker-compose-linux-${compose_arch}"
base_url="https://github.com/docker/compose/releases/download/${compose_version}"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

curl -fsSL "${base_url}/${asset}" -o "${work_dir}/${asset}"
curl -fsSL "${base_url}/${asset}.sha256" -o "${work_dir}/${asset}.sha256"

(
    cd "${work_dir}"
    sha256sum -c "${asset}.sha256"
)

install -d \
    /usr/local/bin \
    /usr/local/lib/docker/cli-plugins \
    /usr/local/libexec/docker/cli-plugins \
    /usr/lib/docker/cli-plugins \
    /usr/libexec/docker/cli-plugins
install -m 0755 "${work_dir}/${asset}" /usr/local/bin/docker-compose

for plugin_dir in \
    /usr/local/lib/docker/cli-plugins \
    /usr/local/libexec/docker/cli-plugins \
    /usr/lib/docker/cli-plugins \
    /usr/libexec/docker/cli-plugins; do
    ln -sf /usr/local/bin/docker-compose "${plugin_dir}/docker-compose"
done

/usr/local/bin/docker-compose version
