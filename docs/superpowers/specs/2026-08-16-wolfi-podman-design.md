# Wolfi Podman Design

## Goal

Add Podman to the Wolfi image as a supported container tool alongside the
existing Docker-in-Docker runtime. Docker remains the default compatibility
contract; Podman is an additional native CLI and rootless runtime for the
`vscode` user.

## Architecture

Install `podman-6.0`, `buildah`, `skopeo`, `shadow-subids`, and `mount` from
Wolfi's signed APK repositories. Podman's package dependencies provide matching
Wolfi builds of `conmon`, `containers-common`, `crun`, and `netavark`.

Podman 6 requires `pasta` for rootless networking and has removed
`slirp4netns` support. Wolfi does not currently package `passt`, so install the
official Homebrew `passt` formula with the image's existing Homebrew foundation.
This reuses a repository-supported, checksummed supply-chain path and keeps
`pasta` on the image-wide `PATH`. Do not download an unverified binary or add a
foreign APK repository.

Configure a non-overlapping 65,536-ID subordinate UID and GID range for
`vscode` after that user exists. Wolfi's `shadow-subids` package does not set
the setuid bit on `newuidmap` and `newgidmap`; enable it explicitly so rootless
user namespaces work. Limit the privilege to those standard mapping helpers.

Install a user-level `storage.conf` with
`rootless_storage_path = "$HOME/.local/share/containers/storage"` and
`fuse-overlayfs` as the overlay mount program. Wolfi's system storage
configuration otherwise directs this workload to root-owned
`/var/lib/containers/storage`. Keep Podman's state separate from Docker's
`/var/lib/docker` volume.

At entrypoint startup, create an owner-only `/run/user/<current-vscode-uid>`,
export it as `XDG_RUNTIME_DIR`, repair ownership of Podman's persistent storage
volume, and make `/` recursively shared when Podman is installed. Computing the
runtime path dynamically preserves Dev Container UID remapping.

Podman does not replace or wrap Docker. The image keeps the `docker` binary,
Docker daemon, Docker group, Docker socket, entrypoint startup behavior, and
`ROR_DOCKER_*` controls unchanged. No `docker` alias or Podman socket is enabled
by default.

## UBlue Relationship

`ublue-os/devcontainer` establishes the useful behavioral pattern: install
Podman, allocate subordinate IDs, enable `newuidmap` and `newgidmap`, use
persistent container storage, make the root mount shared, and prepare cgroup
nesting for nested operation. Its implementation is not copied because it
depends on Fedora packages, `dnf5`, `podman-machine`, bootc conventions, a
broadly writable `/run/user`, and a feature entrypoint that would compete with
this repository's existing Docker entrypoint.

The Wolfi implementation adopts the portable contracts that live testing proves
necessary: native distribution packages, setuid mapping helpers, explicit
rootless storage, `pasta` networking, a per-user runtime directory, shared mount
propagation, and runtime verification. It does not copy UBlue's `timedatectl`
shim, Podman Machine packages, signing parameter file, bash startup bind mount,
or unconditional cgroup reparenting. A privileged Wolfi probe successfully ran
a CPU-limited rootless container with the `cgroupfs` manager without the latter.

## Runtime Behavior

- `docker` continues to use the existing Docker-in-Docker daemon and socket.
- `podman` runs rootless when invoked by `vscode` and does not require a
  long-lived daemon.
- Podman uses its own per-user storage and network configuration.
- A named Dev Container volume persists Podman's user storage independently of
  Docker data.
- The Wolfi devcontainer remains privileged, as already required for Docker
  and nested container workloads.
- Failure to initialize Podman must not change Docker startup or prevent the
  devcontainer command from running.

## Security and Supply Chain

- Consume Podman and its OCI runtime dependencies exclusively from the same
  signed Wolfi repositories as the base image.
- Consume the missing `passt` dependency through the official Homebrew formula,
  whose source or bottle is checksum-verified by Homebrew. This is the same
  package channel already trusted by the image and avoids a new repository or
  ad hoc installer.
- Let Wolfi resolve Podman's runtime dependency set so Podman, conmon, crun,
  and netavark remain compatible and receive normal Wolfi security rebuilds.
- Keep the package set explicit and omit `podman-machine`, which is intended
  for managing a separate VM and is unnecessary inside this Linux container.
- Restrict `/run/user/<uid>` to its owner instead of adopting UBlue's mode
  `0777` on all of `/run/user`.
- Do not expose a Podman API socket or TCP endpoint by default.
- Preserve the existing image SBOM, signing, and vulnerability-scanning
  workflow for the added packages.

## Validation

Add a focused repository contract test that verifies the Wolfi Dockerfile:

- installs `podman-6.0`, `buildah`, `skopeo`, `shadow-subids`, `mount`, and the
  Homebrew `passt` formula;
- defines subordinate UID and GID ranges for `vscode`;
- sets the required setuid bits only on `newuidmap` and `newgidmap`;
- selects `fuse-overlayfs` for rootless Podman storage;
- prepares a dynamic, owner-only `XDG_RUNTIME_DIR` and persistent storage path;
- does not alias or replace the `docker` command.

Extend the Wolfi publish-time runtime contract to run as `vscode` and verify:

- `podman`, `buildah`, and `skopeo` are present;
- `podman info` reports rootless mode, overlay storage, `netavark`, and
  `cgroupfs`;
- a minimal container can be pulled and run with DNS and outbound networking;
- a CPU-limited container and a bind-mounted container both run successfully;
- `buildah info` and `skopeo inspect` succeed as `vscode`;
- the existing Docker version, daemon, and `hello-world` checks still pass.

Local verification uses the focused shell contract test, repository linting,
and a Wolfi devcontainer build when the required build tooling is available.

## Non-Goals

- Replacing Docker or making Podman the implementation behind `docker`.
- Adding Podman to Ubuntu Noble or Debian Trixie.
- Running a Podman API service automatically.
- Supporting `podman machine` inside the devcontainer.
- Refactoring the shared Docker entrypoint or storage-startup code.
