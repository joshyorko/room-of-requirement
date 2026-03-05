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
│  Homebrew Brewfiles (curated tool bundles)            │
│  • cli, cloud, k8s, security, data, dev, ror          │
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
ujust cgroup-check       # Check cgroup v2 memory controller status (k3d/k3s troubleshooting)
ujust info               # Display system configuration
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

## Known Issues

### k3d/k3s in GitHub Codespaces

**Problem:** k3d cluster creation fails in GitHub Codespaces with the error:
```
level=fatal msg="Error: failed to find memory cgroup (v2)"
```

**Root cause:** GitHub Codespaces runs on Azure VMs with cgroup v2, but the outer orchestrator only delegates `cpuset cpu pids` to child cgroups — **not `memory`**. k3s requires the memory controller for pod resource management.

**Diagnosis:** Run `ujust cgroup-check` to verify if the memory controller is delegated. The output will show:
- ✓ Memory controller delegated → k3d/k3s should work
- ⚠ Memory controller NOT delegated → k3d/k3s will fail

**Attempted fix:** The devcontainer image includes `/usr/local/bin/enable-cgroup-memory.sh` which attempts to enable memory controller delegation at container startup. However, this typically fails in Codespaces due to infrastructure restrictions (insufficient permissions to modify the root cgroup).

**Workarounds:**
1. Use Docker Desktop locally (full cgroup delegation)
2. Use DevPod on k3s/k8s clusters (proper cgroup delegation from kubelet)
3. Request GitHub Codespaces team to enable memory controller delegation for your workspace

**Why this doesn't happen elsewhere:**
- **Local Docker Desktop**: Full control of cgroup tree, memory controller always delegated
- **DevPod on k3s**: The k3s node itself requires memory controller for pod limits, so it's delegated to all child containers
- **GitHub Codespaces**: Azure orchestrator restricts delegation for resource isolation

This is a platform limitation of GitHub Codespaces, not a bug in the devcontainer or k3d.

## Security Considerations

- Wolfi OS provides minimal attack surface and rapid CVE patching
- Direct downloads verified with SHA256 checksums
- Homebrew analytics disabled (`HOMEBREW_NO_ANALYTICS=1`)
- All artifacts cryptographically signed via cosign
