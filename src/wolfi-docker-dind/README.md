# Docker-in-Docker (Wolfi)

Docker-in-Docker support for Wolfi-based containers using native Wolfi apk packages.

## Why This Feature?

The official `ghcr.io/devcontainers/features/docker-in-docker` feature doesn't support Wolfi OS. It only supports Debian-based and RHEL-based distributions. This feature provides equivalent functionality using Wolfi's native package ecosystem.

## Features

- **Native Wolfi Packages**: Uses `docker`, `docker-cli`, `containerd`, and `runc` from Wolfi repos
- **Docker Compose**: Optionally installs Docker Compose
- **Buildx**: Optionally installs Docker Buildx for multi-platform builds
- **Automatic Daemon Management**: Includes entrypoint script to start dockerd
- **Cgroup v2 Support**: Properly handles cgroup nesting for nested containers

## Usage

Add to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/joshyorko/devcontainer-features/wolfi-docker-dind:1": {
            "installBuildx": true,
            "installCompose": true
        }
    },
    "privileged": true
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `installBuildx` | boolean | `true` | Install Docker Buildx plugin |
| `installCompose` | boolean | `true` | Install Docker Compose |

## Requirements

- **Wolfi-based container image** (cgr.dev/chainguard/wolfi-base or similar)
- **Privileged mode**: The container must run in privileged mode
- **/var/lib/docker volume**: A volume mount is automatically configured

## How It Works

1. **Install Phase**: The `install.sh` script installs Docker packages via `apk add`
2. **Startup Phase**: The entrypoint `/usr/local/share/docker-init.sh` starts containerd and dockerd
3. **Runtime**: Docker commands work as expected within the container

## Troubleshooting

### Docker daemon won't start

Check the logs:
```bash
cat /tmp/dockerd.log
cat /tmp/containerd.log
```

### Permission denied errors

Ensure the container is running in privileged mode:
```json
{
    "privileged": true
}
```

### Cannot connect to Docker socket

The socket should be at `/var/run/docker.sock`. Verify dockerd is running:
```bash
pgrep dockerd
```
