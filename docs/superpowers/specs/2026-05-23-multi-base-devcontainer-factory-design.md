# Multi-Base Devcontainer Factory Design

## Goal

Transform Room of Requirement from a single Wolfi devcontainer into a multi-base devcontainer image factory while preserving the current Homebrew, mise, `ujust`, shell, and Docker workflow.

## Scope

This design implements the repository shape needed by issue #219:

- `src/common` owns shared config, scripts, Brewfiles, and `justfile`.
- `src/wolfi/.devcontainer` preserves the current Wolfi implementation as the secure/minimal variant.
- `src/ubuntu-noble/.devcontainer` becomes the default Codespaces-compatible variant.
- `src/debian-trixie/.devcontainer` provides the Microsoft Debian comparison baseline.
- Top-level `.devcontainer/devcontainer.json` points at the Ubuntu Noble variant by default.
- `docker-bake.hcl` describes variant builds and tag aliases.
- The build workflow validates variant Dockerfiles and can build a selected variant.

Publishing every GHCR alias from the issue is intentionally staged behind the bake file and workflow inputs. The structure and tag map must exist now; full release automation can be hardened separately without blocking the repo migration.

## Architecture

The repo becomes a factory with three layers:

1. Variant Dockerfiles under `src/<variant>/.devcontainer/`.
2. Shared assets under `src/common/`.
3. Top-level developer entrypoint under `.devcontainer/devcontainer.json`.

Each variant Dockerfile uses the repository root as build context. Shared assets are copied from `src/common`, so the image behavior stays consistent across bases. Wolfi keeps its APK-specific Docker and gcompat workarounds. Ubuntu and Debian use Microsoft devcontainer bases and apt packages for host compatibility.

## Variants

### Ubuntu Noble

Ubuntu Noble is the default Codespaces path.

- Base image: `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`.
- Installs Homebrew, `starship`, `mise`, `zoxide`, and `bbrew`.
- Copies shared shell config, Brewfiles, scripts, post-create hook, and `ujust`.
- Uses Docker-in-Docker feature wiring in `devcontainer.json`.
- Does not include Wolfi APK wrappers.

### Debian Trixie

Debian Trixie is the Skevetter-style comparison baseline.

- Base image: `mcr.microsoft.com/devcontainers/base:trixie`.
- Uses the same shared assets and Homebrew bootstrap as Ubuntu.
- Keeps Docker best-effort through the devcontainer feature.

### Wolfi

Wolfi remains the secure/minimal experimental variant.

- Base image: `cgr.dev/chainguard/wolfi-base:latest`.
- Preserves current Docker/DinD, gcompat suppression, apk wrapper, and Chainguard package logic.
- Copies shared assets from `src/common`.
- Does not remain the default top-level Codespaces image.

## Shared Assets

`src/common` contains:

- `brew/*.Brewfile`
- `config/.bashrc`
- `config/.zshrc`
- `config/mise.toml`
- `config/starship.toml`
- `entrypoint.sh`
- `first-run-notice.txt`
- `justfile`
- `post-create.sh`
- `scripts/*.sh`

The existing paths under `.devcontainer` may remain temporarily as compatibility shims, but all new variant Dockerfiles must source shared assets from `src/common`.

## Build And Tags

`docker-bake.hcl` defines targets:

- `ubuntu-noble`
- `ubuntu-noble-dind`
- `debian-trixie`
- `wolfi`

Alias mapping:

- `latest` -> `ubuntu-noble`
- `codespaces` -> `ubuntu-noble-dind`
- `secure` -> `wolfi`

The existing `build-image.yml` workflow gains a `variant` input and lint/build references to `src/${variant}/.devcontainer`. This keeps the current signing, SBOM, scan, and provenance flow intact while making the build path variant-aware.

## Validation

Minimum local validation:

- `pre-commit run --all-files`
- `docker build -f src/ubuntu-noble/.devcontainer/Dockerfile .`
- `docker build -f src/debian-trixie/.devcontainer/Dockerfile .`
- `docker build -f src/wolfi/.devcontainer/Dockerfile .`

If local image builds are too slow or Docker is unavailable, validate syntax with `hadolint` and `docker buildx bake --print`, then report the unrun build checks.

## Migration Notes

The current Wolfi image is moved by copy first, not deleted first. That keeps a rollback path while the default Codespaces entrypoint changes to Ubuntu. After the new factory paths are proven in CI, `.devcontainer/Dockerfile` can be removed or reduced to a compatibility pointer in a later cleanup.
