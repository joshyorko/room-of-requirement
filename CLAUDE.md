# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Room of Requirement is a modular DevContainer platform built on Wolfi OS (Chainguard). It provides instant-startup development environments with polyglot tooling, supply chain security, and composable features.

## Architecture

```
┌────────────────────────────────────────────────────────┐
│  Wolfi OS Base (cgr.dev/chainguard/wolfi-base)        │
│  └── Homebrew Foundation (/home/linuxbrew/.linuxbrew) │
│       └── Core Tools: mise, starship, zoxide, nushell │
├────────────────────────────────────────────────────────┤
│  DevContainer Features (composable, published to GHCR)│
│  • ror-core (meta), ror-cli-tools, ror-specialty      │
│  • wolfi-docker-dind (rootless Docker-in-Docker)      │
└────────────────────────────────────────────────────────┘
```

**Key components:**
- `.devcontainer/Dockerfile` - Multi-stage Wolfi OS image with Homebrew
- `.devcontainer/brew/*.Brewfile` - Categorized tool bundles (cli, cloud, k8s, security, data, dev)
- `.devcontainer/justfile` - Bluefin-style commands exposed via `ujust`
- `automation/maintenance-robot/` - RCC-powered automated maintenance

## Commands

### Development (ujust)

```bash
ujust bbrew              # Interactive Homebrew package selection (TUI)
ujust brew-install-all   # Install all packages from all Brewfiles
ujust brew-update        # Update Homebrew and packages
ujust docker-status      # Check Docker daemon status
ujust docker-start       # Start Docker daemon
ujust docker-clean       # Prune Docker resources
ujust info               # Display system configuration
ujust playwright-install # Install Playwright browsers
```

### Maintenance Robot (rcc)

```bash
# Full maintenance (updates versions, checksums, lockfile)
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance

# Individual tasks
rcc run -r automation/maintenance-robot/robot.yaml -t update-workflows
rcc run -r automation/maintenance-robot/robot.yaml -t update-downloads
rcc run -r automation/maintenance-robot/robot.yaml -t update-lockfile
rcc run -r automation/maintenance-robot/robot.yaml -t update-homebrew

# Test container build
rcc run -r automation/maintenance-robot/robot.yaml -t test-devcontainer
```

### Python (maintenance robot)

```bash
cd automation/maintenance-robot
pytest                   # Run tests
ruff check .             # Lint Python code
```

## Key Patterns

**Homebrew ownership:** The vscode user (UID 1000) owns `/home/linuxbrew/.linuxbrew` for `brew update` to work. The linuxbrew user is only for initial installation.

**Tool versioning:** Uses mise-en-place for polyglot version management. Default runtimes (node@lts, python@latest, go@latest) are pre-configured in the image.

**Shell configuration:** `.devcontainer/config/.zshrc` is copied to both `/tmp/.zshrc-ror` (backup) and `/home/vscode/.zshrc`. The postCreate command restores it if features overwrite it.

**Docker-in-Docker:** Uses Wolfi's official dockerd-oci-entrypoint. The container runs with `--privileged` for DinD support.

**Allowlist-driven updates:** Maintenance robot uses JSON allowlists (`automation/maintenance-robot/allowlists/`) to constrain which versions can be automatically updated.

## Security Considerations

- Wolfi OS provides minimal attack surface and rapid CVE patching
- Direct downloads verified with SHA256 checksums
- Homebrew analytics disabled (`HOMEBREW_NO_ANALYTICS=1`)
- All artifacts cryptographically signed via cosign
