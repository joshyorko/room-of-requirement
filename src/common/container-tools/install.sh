#!/usr/bin/env bash
set -euo pipefail

bundle="${ROR_CONTAINER_TOOLS_BUNDLE:-/usr/local/share/ror/container-tools}"
root="${ROR_CONTAINER_TOOLS_ROOT:-/}"
manifest="${bundle}/manifest.json"

if [[ "${root}" != /* ]]; then
    echo "Container tools destination root must be absolute" >&2
    exit 1
fi
root="${root%/}"

# Validate the entire bundle before replacing any installed tool. Only the
# documented tool destinations and locally built APK payloads are accepted.
jq -e '
    type == "object" and
    (.go_version | type == "string" and length > 0) and
    (.x_net_version | type == "string" and length > 0) and
    (.artifacts | type == "array" and length > 0) and
    ([.artifacts[].path] | length == (unique | length)) and
    all(.artifacts[];
        type == "object" and
        (.sha256 | type == "string" and test("^[a-f0-9]{64}$")) and
        (.path | type == "string") and
        (if .path == "bin/docker-compose" then
            .destination == "/usr/local/bin/docker-compose"
        elif .path == "bin/docker-buildx" then
            .destination == "/usr/libexec/docker/cli-plugins/docker-buildx"
        elif .path == "bin/containerd" then
            .destination == "/usr/bin/containerd"
        elif .path == "bin/ctr" then
            .destination == "/usr/bin/ctr"
        elif .path == "bin/containerd-shim-runc-v2" then
            .destination == "/usr/bin/containerd-shim-runc-v2"
        else
            (.path | test("^apk/[A-Za-z0-9][A-Za-z0-9._+-]*[.]apk$")) and
            (has("destination") | not)
        end)
    ) and
    ([.artifacts[].path] |
        contains(["bin/docker-compose", "bin/docker-buildx", "bin/containerd",
                  "bin/ctr", "bin/containerd-shim-runc-v2"]))
' "${manifest}" > /dev/null

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT
jq -r '.artifacts[] | [.path, .sha256, (.destination // "-")] | @tsv' \
    "${manifest}" > "${work_dir}/artifacts"

while IFS=$'\t' read -r artifact expected destination; do
    if [[ ! -f "${bundle}/${artifact}" || -L "${bundle}/${artifact}" ]] || \
        [[ "$(realpath --relative-to="${bundle}" "${bundle}/${artifact}")" != "${artifact}" ]]; then
        echo "Missing or unsafe container tools artifact: ${artifact}" >&2
        exit 1
    fi
    checksum="$(sha256sum "${bundle}/${artifact}")"
    if [[ "${checksum%% *}" != "${expected}" ]]; then
        echo "Container tools checksum mismatch: ${artifact}" >&2
        exit 1
    fi
done < "${work_dir}/artifacts"

apks=()
while IFS=$'\t' read -r artifact expected destination; do
    if [[ "${artifact}" == apk/* ]]; then
        apks+=("${bundle}/${artifact}")
    fi
done < "${work_dir}/artifacts"

if [[ "${#apks[@]}" -gt 0 ]] && \
    [[ -f "${root}/etc/os-release" ]] && \
    grep -Eq '^ID=("wolfi"|wolfi)$' "${root}/etc/os-release"; then
    apk_root=()
    if [[ -n "${root}" ]]; then
        apk_root=(--root "${root}")
    fi
    # Disable repositories and network access so relaxed signature checking
    # applies only to checksum-verified local files. Missing dependencies fail.
    apk "${apk_root[@]}" add --no-network --repositories-file /dev/null \
        --allow-untrusted --upgrade "${apks[@]}"
fi

while IFS=$'\t' read -r artifact expected destination; do
    if [[ "${destination}" != "-" ]]; then
        install -D -m 0755 "${bundle}/${artifact}" "${root}${destination}"
    fi
done < "${work_dir}/artifacts"

for plugin_dir in \
    /usr/local/lib/docker/cli-plugins \
    /usr/local/libexec/docker/cli-plugins \
    /usr/lib/docker/cli-plugins \
    /usr/libexec/docker/cli-plugins; do
    install -d "${root}${plugin_dir}"
    ln -sfn "${root}/usr/local/bin/docker-compose" "${root}${plugin_dir}/docker-compose"
    if [[ "${plugin_dir}" != /usr/libexec/docker/cli-plugins ]]; then
        ln -sfn "${root}/usr/libexec/docker/cli-plugins/docker-buildx" \
            "${root}${plugin_dir}/docker-buildx"
    fi
done

install -D -m 0644 "${manifest}" "${root}/usr/share/ror/container-tools/manifest.json"
