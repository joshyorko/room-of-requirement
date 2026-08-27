# DevPod Home Persistence

The DevPod configurations mount the standard `vscode` home at
`/home/vscode`:

```text
source=ror-vscode-home-${devcontainerId},target=/home/vscode,type=volume
```

The Kubernetes DevPod provider maps `type=volume` mounts to subdirectories of
the workspace PVC. The `${devcontainerId}` substitution scopes the private
home storage to one workspace/configuration on local Docker and Kubernetes
DevPod. The source name is therefore a storage namespace; it does not change
`HOME` or relocate any tool. The existing workspace mount remains the durable
source for `/workspaces/<workspace>`.

The existing mise, npm, shell-history, and Wolfi Podman child mounts remain in
place deliberately. They preserve data created by earlier configurations while
the new parent mount persists every other normal user-home path, including
`.codex`, `.local/bin`, `.config`, and VS Code state. No tool-specific home or
`automation-jat` mount is required.

## First use

On a new Kubernetes workspace, DevPod initializes volume subdirectories from
the image before starting the container. The image entrypoint also runs
`/usr/local/bin/seed-vscode-home.sh`, which copies only missing baseline files:

- `.zshrc`
- `.bashrc`
- `.config/starship.toml`
- `.config/mise/config.toml`

Existing files, including private configuration and authentication state, are
never replaced. The bootstrap reconciles ownership for `vscode` without
rewriting permission bits.

## Safe validation

Use non-secret marker files for before/after checks. The following records the
mount source, target, owner, mode, and SHA-256 checksums without printing file
contents:

```bash
workspace=josh-room

devpod ssh "${workspace}" --provider kubernetes --command '
set -eu
findmnt -T /home/vscode -o SOURCE,TARGET,FSTYPE,OPTIONS || mount | grep " /home/vscode "
mkdir -p /home/vscode/.codex /home/vscode/.local/bin /home/vscode/.config
printf "%s\n" "ror-home-persistence" > /home/vscode/.codex/ror-home-check
printf "%s\n" "user-tool" > /home/vscode/.local/bin/ror-home-tool
printf "%s\n" "ordinary-config" > /home/vscode/.config/ror-home-check
chmod 600 /home/vscode/.codex/ror-home-check
chmod 700 /home/vscode/.local/bin/ror-home-tool
for path in /home/vscode/.codex/ror-home-check /home/vscode/.local/bin/ror-home-tool /home/vscode/.config/ror-home-check; do
  stat -c "%u:%g %a %n" "${path}"
  sha256sum "${path}"
done
'
```

Capture the output, then perform an intentional stop/start and run the same
read-only inspection and checksum block again:

```bash
devpod stop "${workspace}"
devpod up "${workspace}" --provider kubernetes --open-ide=false

devpod ssh "${workspace}" --provider kubernetes --command '
set -eu
findmnt -T /home/vscode -o SOURCE,TARGET,FSTYPE,OPTIONS || mount | grep " /home/vscode "
for path in /home/vscode/.codex/ror-home-check /home/vscode/.local/bin/ror-home-tool /home/vscode/.config/ror-home-check; do
  stat -c "%u:%g %a %n" "${path}"
  sha256sum "${path}"
done
'
```

The three hashes and mode/ownership lines must match. Repeat the same check
after an operator-controlled pod replacement or memory-limit recovery, using
the exact workspace pod and PVC; do not reset or delete the workspace.

## Existing workspaces and rollback

An existing Kubernetes PVC created before this mount was added may need the
`devpod/ror-vscode-home-<devcontainer-id>` subdirectory prepared once before the kubelet accepts
the new `subPath`. If the pod reports a missing subpath, stop before repeated
recreate attempts and use the cluster's approved maintenance-pod procedure to
create that directory on the existing workspace PVC. Keep the PVC and current
child cache mounts intact, then start the workspace and verify ownership and
checksums. Do not use `devpod delete --reset`; it deletes the durable workspace
claim and cannot recover the old container writable layer.

To roll back, restore the previous DevContainer configuration and recreate the
pod without deleting the PVC. Leave the `ror-vscode-home-<devcontainer-id>` storage namespace in
place so it remains recoverable, and leave the existing child cache volumes
untouched. The prior configuration will continue using its original cache
mounts while the generic home data waits for a later retry.
