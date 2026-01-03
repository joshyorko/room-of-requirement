[![Open in DevPod!](https://devpod.sh/assets/open-in-devpod.svg)](https://devpod.sh/open#https://github.com/joshyorko/room-of-requirement)

# Room of Requirement 🧙

> _A modular, secure, bleeding-edge DevContainer platform built on Wolfi OS_

**Instant startup. Homebrew-first tooling. Supply chain security. Curated Brewfiles.**

---

## 🚀 Quick Start

### Option 1: Use the Pre-built Image (Recommended)

Add to your project's `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/joshyorko/ror:latest"
}
```

Everything is pre-baked into the image - no features required! Core tools (mise, starship, zoxide, nushell) are ready to use. Additional tools like rcc are available via `ujust bbrew` → select `ror`.

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
┌─────────────────────────────────────────────────────────────┐
│                     ror:latest Image                        │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Wolfi OS Base (cgr.dev/chainguard/wolfi-base)         ││
│  │  • Minimal attack surface  • glibc compatible          ││
│  │  • Rapid CVE patching      • UTF-8 locale configured   ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Homebrew Foundation (First-Class Package Manager)     ││
│  │  • Core tools pre-installed: mise, starship, zoxide    ││
│  │  • Curated Brewfiles for on-demand tool installation   ││
│  │  • /home/linuxbrew/.linuxbrew in PATH                  ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Curated Brewfiles (.devcontainer/brew/)               ││
│  │  • core.Brewfile  - mise, starship, zoxide, nushell    ││
│  │  • dev.Brewfile   - bat, eza, fzf, ripgrep, jq, yq     ││
│  │  • cloud.Brewfile - aws, azure, terraform, k8s tools   ││
│  │  • ror.Brewfile   - rcc, uv, gh, duckdb, sqlite        ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

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
| **mise** | Polyglot version manager (Node, Python, Go, etc.) |
| **starship** | Cross-shell prompt with git/tool status |
| **zoxide** | Smart directory navigation (`z` command) |
| **nushell** | Modern shell alternative |


### On-Demand Brewfiles

Install additional tool bundles using the TUI:

```bash
ujust bbrew          # Interactive TUI to select Brewfiles
ujust brew-install-all  # Install everything
```

| Brewfile | Tools Included |
|----------|----------------|
| **core** | mise, starship, zoxide, nushell |
| **dev** | bat, eza, fd, fzf, ripgrep, jq, yq, htop, tmux, git-lfs |
| **cloud** | aws-cli, azure-cli, terraform, kubectl, helm, k9s, k3d, dagger, devspace |
| **ror** | rcc, uv, gh, duckdb, sqlite |

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
mise use python@3.12
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

### Wolfi OS Foundation
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
- Built-in via Wolfi's official `docker-dind` package
- Uses `--privileged` mode (required for DinD functionality)

---

## 🏗️ Repository Structure

```
room-of-requirement/
├── .devcontainer/           # DevContainer configuration
│   ├── devcontainer.json    # Container configuration
│   ├── Dockerfile           # Wolfi OS + Homebrew base image
│   ├── post-create.sh       # Post-creation hydration script
│   ├── justfile             # ujust commands (bbrew, etc.)
│   └── brew/                # Curated Brewfiles
│       ├── core.Brewfile    # mise, starship, zoxide, nushell
│       ├── dev.Brewfile     # CLI tools, terminal utilities
│       ├── cloud.Brewfile   # Cloud CLIs, Kubernetes, IaC
│       └── ror.Brewfile     # rcc, uv, gh, databases
├── templates/               # Project starter templates
│   └── ror-starter/         # Basic RoR template
├── automation/              # Maintenance automation
│   └── maintenance-robot/   # RCC-powered version updater
└── specs/                   # Architecture specifications
```

---

## 🎛️ Customization Examples

### Standard Setup (Everything Pre-baked)

```json
{
  "image": "ghcr.io/joshyorko/ror:latest"
}
```

All tools are pre-installed: mise, starship, zoxide, nushell. Use `ujust bbrew` for additional tools (rcc, uv, gh available via `ror` Brewfile).

### With Additional Kubernetes Tools

```json
{
  "image": "ghcr.io/joshyorko/ror:latest",
  "postCreateCommand": "brew bundle --file=/tmp/brew/k8s.Brewfile"
}
```

### With Project-Level Brewfile

```json
{
  "image": "ghcr.io/joshyorko/ror:latest",
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

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

## Why Room of Requirement?

> _"It is a room that a person can only enter when they have real need of it. Sometimes it is there, and sometimes it is not, but when it appears, it is always equipped for the seeker's needs."_

Because every developer deserves a workspace that adapts to their needs—just like magic. 🪄
