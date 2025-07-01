# Devcontainer BuildKit and Moby Cache Setup

This guide explains how to enable Docker BuildKit inside the devcontainer, warm a Moby cache on start, and use `docker compose bake` for fast image builds.

## 1. Current Environment Overview
- **devcontainer.json** builds the container from `.devcontainer/Dockerfile` and installs Docker-in-Docker with common utilities.
- The Dockerfile pulls a shared `.zshrc` which sets `COMPOSE_BAKE=true` to instruct Docker Compose to prefer BuildKit.
- BuildKit can be toggled globally using `DOCKER_BUILDKIT=1`. A warmed "Moby cache" refers to pre-populated BuildKit layers so initial builds run quickly.

## 2. Enable BuildKit
Add BuildKit variables and arguments in `.devcontainer/devcontainer.json`:
```json
"build": {
  "dockerfile": "Dockerfile",
  "args": { "BUILDKIT_INLINE_CACHE": "1" }
},
"remoteEnv": {
  "DOCKER_BUILDKIT": "1",
  "COMPOSE_DOCKER_CLI_BUILD": "1",
  "COMPOSE_BAKE": "true"
},
"features": {
  "buildkit": {}
}
```
These settings ensure BuildKit is used for all Docker commands in the devcontainer.

## 3. Pre‑Warm the Moby Cache
Create `.devcontainer/init-buildkit.sh`:
```bash
#!/usr/bin/env bash
set -e
if command -v docker >/dev/null; then
  echo "Warming BuildKit cache via docker compose bake…"
  docker compose bake --pull --load
fi
```
Then extend `postCreateCommand`:
```json
"postCreateCommand": "curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; set -e && curl -sS https://webinstall.dev/k9s | sh && curl -LsSf https://astral.sh/uv/install.sh | sh && bash .devcontainer/init-buildkit.sh"
```
The script runs on container creation, fetching cache layers so subsequent builds are faster.

## 4. Verification Steps
- Check BuildKit builder size: `docker buildx du`.
- Clean caches if needed: `docker builder prune`.
- Benchmark build times before/after enabling the cache by running `time docker compose build`.

## 5. Alternative Approaches
- **Buildx inline cache** – push images with `--build-arg BUILDKIT_INLINE_CACHE=1` so future builds reuse layers without separate cache exports.
- **devcontainers/cache feature** – mount a named volume for BuildKit caches to persist across container restarts.

Use inline caching when publishing images and `devcontainers/cache` when persistent local caches are preferred.
