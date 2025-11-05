# Copilot Instructions for Room of Requirement

## Project Overview
This is a production-ready DevContainer template called "Room of Requirement" - a magical cloud-native development environment. The project provides a customizable Ubuntu Noble (24.04) container with Docker, Kubernetes (k3d), and development tools pre-configured.

## Architecture & Key Components

### Multi-stage Dockerfile (`.devcontainer/Dockerfile`)
- **Base stage**: Ubuntu 24.04 with first-run notice
- **System deps**: Essential packages including browser dependencies for GUI testing
- **Dev tools**: C/C++ development, debugging tools (gdb, lldb, valgrind)
- **Cloud tools**: kubectl, AWS CLI, k3d, k9s, MinIO client, Sema4.AI tools
- **Final stage**: ZSH setup with custom dotfiles from external repo

### DevContainer Configuration
- Uses docker-in-docker feature (v2.12.4) for Docker daemon access
- In Kubernetes/DevPod: Docker runs in a sidecar container sharing network/storage
- Runs with `--privileged` flag for container-in-container capabilities
- Custom `postCreateCommand` runs post-create.sh script with resilient error handling
- Volume mount for UV cache to persist Python package downloads
- Remote user: `vscode` with ZSH as default shell

## Critical Workflows

### Building & Publishing
```bash
# Local development - use VS Code Dev Containers extension
# Production - GitHub Actions automatically builds and pushes to GHCR

# Manual CLI build (if needed):
npx @devcontainers/cli build --workspace-folder . --image-name ghcr.io/joshyorko/ror:latest
```

### CI/CD Pipeline (`.github/workflows/cicd.yaml`)
- Triggered on push to `main` or manual dispatch
- Builds DevContainer using `@devcontainers/cli`
- Pushes to GitHub Container Registry (`ghcr.io/joshyorko/ror`)
- Tags both SHA and `latest`
- Generates detailed build summary with usage examples

## Project-Specific Conventions

### File Organization
- `.devcontainer/`: Core container configuration
- `.github/workflows/`: CI/CD automation
- `first-run-notice.txt`: Welcome message shown on container startup

### External Dependencies
- **Dotfiles**: Pulls ZSH config from `joshyorko/.dotfiles` repo
  - Downloads `.zshrc` and `scrapeCrawl.py` from external repo during build
  - Clones ZSH plugins: `zsh-autosuggestions` and `zsh-syntax-highlighting`
  - Sets proper ownership for `vscode` user in `/home/vscode/.oh-my-zsh/custom/plugins`
- **Cloud Tools**: Direct downloads from official sources (not package managers)
- **Sema4.AI**: Specific version pinning for `action-server` (v2.14.0) and `rcc` (v18.5.0)
  - `action-server`: AI automation server from Sema4.AI platform
  - `rcc`: Robocorp Control Room client for task automation
  - Both installed to `/usr/local/bin/` with execute permissions

### Magic Commands & Features
```bash
# Post-create auto-installs these tools:
k3d --version          # Kubernetes in Docker
k9s version           # Kubernetes CLI UI
uv --version          # Python package manager
duckdb --version      # Embedded analytics database

# Sema4.AI automation tools:
action-server version    # AI action automation server
rcc --version              # Robocorp Control Room client
# Example usage:
# action-server new      # Create new action project
# rcc create             # Create new robot/automation

# Custom shell enhancement:
# - ZSH autosuggestions and syntax highlighting plugins
# - Custom .zshrc from external dotfiles repo
# - scrapeCrawl.py utility script in home directory
```

## Integration Points

### Docker Integration
- Docker-in-Docker pattern using DevContainer feature
- In local environments: Starts Docker daemon inside the container
- In Kubernetes/DevPod: Uses sidecar container pattern for Docker daemon
- Runs with privileged mode for full container capabilities
- Compatible with Docker Desktop, DevPod on Kubernetes, and other container runtimes

### Kubernetes Development
- k3d for local cluster creation
- kubectl pre-configured
- k9s for interactive cluster management

### VS Code Extensions
- `ms-azuretools.vscode-containers`: DevContainer management
- `sema4ai.sema4ai`: AI/automation development
  - Provides project templates for AI actions and automations
  - Integrates with `action-server` and `rcc` tools
  - Supports robot framework development
- `github.vscode-github-actions`: Workflow editing
- `ms-python.python`: Python development with uv integration

### Sema4.AI Integration Patterns
- **Version Strategy**: Pin exact versions in Dockerfile for reproducibility
- **Installation**: Direct binary downloads to `/usr/local/bin/` (not package managers)
- **Development Flow**:
  - Use `action-server new` to create AI action projects
  - Use `rcc` for Robocorp automation workflows
  - VS Code extension provides templates and debugging support

## Development Patterns

When modifying this DevContainer:
1. **Dockerfile changes**: Use multi-stage pattern to keep images lean
2. **Tool versions**: Pin specific versions for reproducibility (see Sema4.AI example)
3. **Package management**: Prefer official installers over apt packages for cloud tools
4. **Customization**: Edit `devcontainer.json` features rather than Dockerfile for common tools
5. **Testing**: Use the CI/CD pipeline to validate changes before merging

## Quick Start for Contributors
```bash
# Open in VS Code with Dev Containers extension
# Container will auto-build and install all dependencies
# First-run notice provides helpful commands to try
```
