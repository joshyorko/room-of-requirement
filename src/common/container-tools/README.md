# Rebuilt container tools

The images rebuild container tools with the Go toolchain and `golang.org/x/net`
versions in `sources.json`. Updating a development Go installation does not repair
Go code embedded in previously compiled executables.

Release archives, their checksums, and upstream revisions are pinned in that
manifest. The Go builder image is pinned in each variant Dockerfile. Builds check
embedded Go metadata and command versions before producing an artifact manifest.
Source downloads have connection and transfer limits. Compilation defaults to two
Go workers; `GOMAXPROCS` can override that build-only limit.

Compose, Buildx, and containerd are static binaries. Ubuntu and Debian use Docker
CE instead of Moby and reapply the verified binaries after the upstream DinD
feature. The local feature lives under `.devcontainer/features/` because the
pinned DevContainer CLI requires local features beneath that directory.

Wolfi rebuilds Buildah, Podman, and Skopeo against Wolfi's native libraries.
Podman and Buildah retain GPGME signing, storage drivers, and the original native
build tags. Podman retains its remote client, rootless port helper, Quadlet,
systemd units, generators, and package aliases.

Native tools use locally produced APK revision `r1000`, with Room of Requirement
as maintainer. They are not upstream Wolfi release artifacts. Installation checks
all artifact SHA256 values first. The unsigned local APK transaction disables
repositories and networking; existing runtime dependencies must satisfy it.
The artifact/source manifest is retained at
`/usr/share/ror/container-tools/manifest.json` in each image.

To update a dependency, update its release URL, checksum, and revision in
`sources.json`. For a Go update, update its manifest version and all pinned Go
builder image references together. Run the container-tool tests, feature-aware
image builds, runtime smoke checks, and immutable-image Grype gate before shipping.
Do not add vulnerability ignores to make an unpatched tool pass.
