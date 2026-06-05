[![Open in DevPod!](https://devpod.sh/assets/open-in-devpod.svg)](https://devpod.sh/open#https://github.com/joshyorko/room-of-requirement)

# Room of Requirement 🧙

> _A multi-base DevContainer image factory with a Homebrew-first developer workflow_

**Codespaces-compatible by default. Wolfi preserved for secure/minimal experiments. Homebrew, mise, and `ujust` everywhere.**

---

## 🚀 Quick Start

### Option 1: Use the Pre-built Image (Recommended)

Add to your project's `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/joshyorko/room-of-requirement:latest"
}
```

`latest` points at the Ubuntu Noble variant, which is the default Codespaces path. Core tools like `mise`, `starship`, `zoxide`, and `bbrew`, plus default Node, Go, and Ruby runtimes are ready to use. Additional tools like `gh`, `uv`, `sqlite`, `duckdb`, `rcc`, `action-server`, `codex`, `claude-code`, `fizzy-cli-master`, `fizzy-popper-self-hosted`, `fizzy-symphony`, and `oracle` are available via `ujust bbrew` -> select `ror`.

Published variant tags:

| Tag | Variant | Purpose |
|-----|---------|---------|
| `latest` | Ubuntu Noble | Default general-purpose image |
| `codespaces` | Ubuntu Noble + DinD | Default GitHub Codespaces path |
| `ubuntu-noble` | Ubuntu Noble | Microsoft Ubuntu base |
| `ubuntu-noble-dind` | Ubuntu Noble + DinD | Explicit Docker-in-Docker alias |
| `debian-trixie` | Debian Trixie | Microsoft Debian comparison baseline |
| `wolfi` | Wolfi | Chainguard secure/minimal variant |
| `secure` | Wolfi | Secure/minimal alias |

### Option 2: Open This Repository

1. Open in VS Code with Dev Containers extension
2. Click "Reopen in Container"
3. Start coding in under 60 seconds!

### Option 3: DevPod

Click the badge at the top or run:
```bash
devpod up https://github.com/joshyorko/room-of-requirement
```

---

## 📦 Architecture Overview

```
room-of-requirement/
├── .devcontainer/                  # Default local/Codespaces entrypoint
├── src/
│   ├── ubuntu-noble/.devcontainer/ # Default Microsoft Ubuntu variant
│   ├── debian-trixie/.devcontainer # Microsoft Debian baseline
│   ├── wolfi/.devcontainer/        # Chainguard secure/minimal variant
│   └── common/                     # Shared Brewfiles, config, scripts, ujust
└── docker-bake.hcl                 # Dockerfile-only inspection targets
```

All variants share the same Homebrew-first workflow. Base images provide OS compatibility, Homebrew provides CLI tools, mise provides language runtimes, `ujust` provides user-facing commands, and Dev Container Features provide platform plumbing such as Docker-in-Docker.

---

## 🍺 Homebrew-First Philosophy

Room of Requirement uses **Homebrew as the first-class package manager**. Instead of custom DevContainer Features for each tool, we leverage Homebrew's vast ecosystem with curated Brewfiles.

### Why Homebrew-First?

- **Simplified maintenance** - No custom install scripts to maintain
- **Faster updates** - Tools update via `brew upgrade`, not image rebuilds
- **User choice** - Install only what you need via `ujust bbrew`
- **Familiar workflow** - Standard Homebrew commands work everywhere

### Pre-installed Tools (Baked into Image)

These are baked into the image for instant availability:

| Tool | Purpose |
|------|---------|
| **mise** | Polyglot version manager (Node, Python, Go, Ruby, etc.) |
| **starship** | Cross-shell prompt with git/tool status |
| **zoxide** | Smart directory navigation (`z` command) |
| **bbrew** | Bold Brew TUI baked in for browsing optional Brewfile installs |


### Curated Brewfiles

The `ror` bundle is opt-in instead of installed during post-create. Install bundles using the TUI, or pre-download the RoR bundle into the Homebrew cache:

```bash
ujust bbrew          # Interactive TUI to select Brewfiles
ujust brew-install-all  # Install everything
ujust brew-download-ror # Download the RoR Brewfile artifacts without installing
```

| Brewfile | Tools Included |
|----------|----------------|
| **core** | mise, starship, zoxide, bbrew |
| **dev** | bat, eza, fd, fzf, ripgrep, jq, yq, htop, tmux, git-lfs |
| **cloud** | aws-cli, azure-cli, terraform, kubectl, helm, k9s, k3d, dagger, devspace |
| **ror** | uv, sqlite, duckdb, gh, codex, claude-code, rcc, action-server, t3code-cli-main, fizzy-cli-master, fizzy-popper-self-hosted, fizzy-symphony, oracle |

---

## 🏭 Building Variants

Inspect the Dockerfile-only build plan:

```bash
docker buildx bake --print
```

Build a raw Dockerfile layer for debugging:

```bash
docker build -f src/ubuntu-noble/.devcontainer/Dockerfile .
docker build -f src/debian-trixie/.devcontainer/Dockerfile .
docker build -f src/wolfi/.devcontainer/Dockerfile .
```

Build a runnable image with Dev Container feature processing:

```bash
devcontainer build --workspace-folder . --config src/ubuntu-noble/.devcontainer/devcontainer.json
```

Published GHCR images are built with `devcontainer build`, not raw `docker build`
or `docker buildx bake`, so Docker-in-Docker and other Dev Container Features are
present in image consumers such as Codespaces and DevPod.

---

## 🛠️ Tool Management with mise

Room of Requirement uses [mise-en-place](https://mise.jdx.dev/) (installed via Homebrew) for polyglot version management:

```bash
# Check active tool versions
mise list

# Install project-specific tools from .mise.toml
mise install

# Use specific versions
mise use node@20
mise use python@3.15.0
```

### Project Configuration

Create a `.mise.toml` in your project root:

```toml
[tools]
node = "20"
python = "3.12"
go = "1.22"

[env]
MY_VAR = "value"
```

Tool versions automatically switch when you `cd` into the project directory.

---

## 💎 Ruby and Rails

Ruby is installed by default via `mise`. Use `mise` to pin a different version when needed:

```bash
ruby --version
mise use -g ruby@latest
gem install rails
```

This keeps Ruby isolated to `mise` (no `sudo gem` and no Homebrew Ruby symlink conflicts).

Optional wrappers are available if you prefer `ujust`:

```bash
ujust ruby-enable 3.4
ujust rails-enable 3.4 8.1.2
```

---

## 📋 Adding Custom Tools

### Option 1: Project-Level Brewfile

Add a `Brewfile` to your project root - it will be automatically installed on container creation:

```ruby
# Your project's Brewfile
brew "kubectl"
brew "helm"
brew "your-custom-tool"
```

### Option 2: Use Curated Brewfiles

Select from the pre-configured bundles:

```bash
ujust bbrew  # Opens TUI to select Brewfiles
```

### Option 3: Direct Homebrew

Just use Homebrew directly:

```bash
brew install <package>
brew tap <tap-name>
brew bundle --file=<path-to-Brewfile>
```

---

## 🔐 Security

### Wolfi OS Variant
- **Minimal attack surface**: Only essential packages installed
- **Rapid CVE patching**: Chainguard's security-focused distribution
- **glibc compatible**: Works with most Linux binaries (native glibc, not musl like Alpine)
  - **Note**: `gcompat` is not needed and not available in Wolfi repos
  - VS Code DevContainer gcompat installation is disabled via `DEV_CONTAINERS_SKIP_GCOMPAT_INSTALL=true`

### Supply Chain Security
- **SBOM generation**: Every image includes a Software Bill of Materials
- **Cosign signatures**: All artifacts cryptographically signed
- **CVE scanning**: Critical vulnerabilities block releases

### Docker-in-Docker
- Ubuntu Noble and Debian use the official Dev Container Docker-in-Docker feature.
- Wolfi uses Chainguard's native `docker-dind` packages.
- All Docker-capable variants use `--privileged` mode.

---

## 🏗️ Repository Structure

```
room-of-requirement/
├── .devcontainer/           # Default devcontainer, points at Ubuntu Noble
├── src/
│   ├── common/              # Shared Brewfiles, config, scripts, post-create
│   ├── ubuntu-noble/        # Default Microsoft Ubuntu variant
│   ├── debian-trixie/       # Microsoft Debian baseline variant
│   └── wolfi/               # Chainguard secure/minimal variant
├── docker-bake.hcl          # Dockerfile-only inspection targets
├── templates/               # Project starter templates
├── automation/              # Maintenance automation
└── specs/                   # Architecture specifications
```

---

## 🎛️ Customization Examples

### Standard Setup (Core Tools Pre-baked)

```json
{
  "image": "ghcr.io/joshyorko/room-of-requirement:latest"
}
```

Core tools are pre-installed: mise, starship, zoxide, bbrew, plus default Node, Go, and Ruby runtimes. Use `ujust bbrew` for additional tools from the curated Brewfiles, including the `ror` bundle.

### With Additional Kubernetes Tools

```json
{
  "image": "ghcr.io/joshyorko/room-of-requirement:latest",
  "postCreateCommand": "brew bundle --file=/tmp/brew/k8s.Brewfile"
}
```

### With Project-Level Brewfile

```json
{
  "image": "ghcr.io/joshyorko/room-of-requirement:latest",
  "postCreateCommand": "brew bundle --file=Brewfile"
}
```

Create a `Brewfile` in your project root with your custom tools.

---

## 🔄 Automated Maintenance

The repository includes an RCC-powered maintenance robot that:

- Tracks PyPI package versions for the maintenance robot itself
- Updates GitHub Actions workflow dependencies
- Tracks Homebrew formula versions

```bash
# Run full maintenance
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance
```

See [automation/maintenance-robot/README.md](automation/maintenance-robot/README.md) for details.

---

## 🔧 Troubleshooting

### GitHub Copilot Chat Extension Error in Codespaces

If you encounter the error `TypeError: Cannot read properties of undefined (reading 'bind')` when using GitHub Copilot Chat in Codespaces:

**Solution**: The devcontainer configuration explicitly includes the `github.copilot` and `github.copilot-chat` extensions to ensure proper initialization. If you still encounter issues:

1. **Reload the window**: Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac) and run "Developer: Reload Window"
2. **Rebuild the container**: Press `Ctrl+Shift+P` and run "Dev Containers: Rebuild Container"
3. **Check extension versions**: Ensure you're using stable (not pre-release) versions of the Copilot extensions

**Why this happens**: The Copilot Chat extension requires certain VS Code APIs to be available during initialization. Explicitly declaring the extensions in the devcontainer configuration ensures they are properly installed and initialized in the correct order.

### Mise Permission Issues in Codespaces

If you encounter permission errors when running `mise install` in GitHub Codespaces:

```bash
mise ERROR Failed to install tools: core:node@lts, core:python@latest, core:go@latest
core:node@lts: failed create_dir_all: ~/.local/share/mise/installs/node/24.13.0: Permission denied (os error 13)
```

**Solution**: The container automatically fixes mise cache directory permissions on startup in Codespaces. If you still encounter issues after the container starts:

1. **Restart your terminal**: Close and reopen the terminal to ensure permissions are applied
2. **Reload the window**: Press `Ctrl+Shift+P` and run "Developer: Reload Window"
3. **Manual fix**: Run `sudo chown -R vscode:vscode ~/.local/share/mise` to fix permissions

**Why this happens**: GitHub Codespaces mounts named volumes with root ownership by default. The entrypoint script detects Codespaces and automatically fixes permissions for the mise cache directory during container initialization, ensuring mise commands work properly.

### Docker in DevPod

The published Ubuntu and Debian streams use the official Docker-in-Docker Dev
Container Feature. The Wolfi stream uses Docker packages baked into the image.
All published streams are expected to have `docker` on `PATH` and a daemon
started by the container entrypoint. The image also ships
`/etc/docker/daemon.json` with `fuse-overlayfs` as the storage driver so nested
container runs work under project-container hosts such as DevPod and
Codespaces. `docker info` and `docker run --rm hello-world` should work without
a manual `ujust` repair step.

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

## Why Room of Requirement?

> _"It is a room that a person can only enter when they have real need of it. Sometimes it is there, and sometimes it is not, but when it appears, it is always equipped for the seeker's needs."_

Because every developer deserves a workspace that adapts to their needs—just like magic. 🪄
