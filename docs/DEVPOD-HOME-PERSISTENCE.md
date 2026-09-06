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

The existing mise, npm, and shell-history child mounts remain in place
deliberately. They preserve caches created by earlier configurations while the
parent mount persists every other normal user-home path, including `.codex`,
`.local/bin`, `.config`, the Homebrew cache, and VS Code state. No
tool-specific home or `automation-jat` mount is required.

Docker and Wolfi Podman graph stores use the same workspace suffix:

```text
source=ror-docker-data-${devcontainerId},target=/var/lib/docker,type=volume
source=ror-wolfi-podman-storage-${devcontainerId},target=/home/vscode/.local/share/containers/storage,type=volume
```

This prevents two local Docker-provider workspaces from attaching independent
daemons to the same graph store. The Kubernetes provider maps these names to
separate workspace-PVC subdirectories.

The fallback Docker starter uses the effective data-root filesystem to choose
storage. Kernel overlay uses `fuse-overlayfs` when available, otherwise `vfs`.
A `fuse.fuse-overlayfs` backing store uses `vfs`; nesting another FUSE overlay
there is not reliable. Selected graph drivers explicitly use Docker's classic
image store (`features.containerd-snapshotter=false`), including on Docker 29.
An explicit conflicting containerd-store setting fails with a diagnostic;
`ROR_DOCKER_STORAGE_DRIVER=default` leaves that explicit setting in control.
Changing image stores can hide the other store's images and containers from
Docker's listing. The starter does not delete or migrate either store; preserve
the old data and configuration for operator-controlled recovery.

## First use

On a new Kubernetes workspace, DevPod initializes volume subdirectories from
the image before starting the container. The image entrypoint also runs
`/usr/local/bin/seed-vscode-home.sh`, which copies only missing baseline files:

- `.zshrc`
- `.bashrc`
- `.config/starship.toml`
- `.config/mise/config.toml`
- `.config/containers/storage.conf` on images that provide a Podman baseline

Existing files, including private configuration and authentication state, are
never replaced. The bootstrap adjusts only a newly created object or a
root-owned mount root. It does not recursively change existing descendants, so
subordinate container IDs and special permission bits remain intact.

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

## Existing workspaces and graph-store migration

Existing `ror-docker-data` and `ror-wolfi-podman-storage` volumes are never
renamed, copied, or deleted automatically. A workspace starts with a new empty
scoped graph store after adopting this configuration. Keep the old volumes as
the rollback source unless an operator deliberately migrates their contents.

For the local Docker provider, stop every container using the old graph store,
take the platform-approved backup, create the exact scoped destination volume,
and copy into that empty destination with an approved maintenance container.
The copy must preserve numeric owners, modes, links, extended attributes, and
special bits. Verify metadata and daemon contents from the destination before
retiring the old volume. Do not attach the old store to two running daemons and
do not use `docker volume rm` as part of migration.

For Kubernetes, use the cluster's approved maintenance-pod procedure to create
the new subdirectory and perform the same stopped, metadata-preserving copy
within the existing workspace PVC. An existing PVC may likewise need the
`devpod/ror-vscode-home-<devcontainer-id>` subdirectory prepared before the
kubelet accepts the home `subPath`. If the pod reports a missing subpath, stop
before repeated recreate attempts. Keep the PVC and cache mounts intact. Do
not use `devpod delete --reset`; it deletes the durable workspace claim and
cannot recover the old container writable layer.

The obsolete `ror-homebrew-cache` mount targeted linuxbrew's home, while brew
running as `vscode` caches under `/home/vscode`. Its mount declaration is
removed, but the old named volume is not deleted. Inspect and retain it until
the normal home-backed cache has been verified.

To roll back, restore the previous DevContainer configuration and recreate the
pod without deleting the PVC or either graph-store volume. Leave the
`ror-vscode-home-<devcontainer-id>` storage namespace and scoped graph stores in
place so they remain recoverable. The prior configuration will continue using
its original stores while the scoped data waits for a later retry.
