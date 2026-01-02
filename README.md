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

Everything is pre-baked into the image - no features required! Core tools (mise, starship, zoxide, nushell) and Sema4.AI tools (action-server, rcc) are ready to use.

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
│  │  • core.Brewfile    - mise, starship, zoxide, nushell  ││
│  │  • cli.Brewfile     - bat, eza, fzf, ripgrep, jq, yq   ││
│  │  • k8s.Brewfile     - kubectl, helm, k9s, dagger       ││
│  │  • cloud.Brewfile   - aws-cli, azure-cli, terraform    ││
│  │  • security.Brewfile - cosign, grype, syft, trivy      ││
│  │  • data.Brewfile    - duckdb, sqlite, httpie           ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              DevContainer Features (Minimal)                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  ror-specialty                        │  │
│  │   Tools NOT available in Homebrew:                   │  │
│  │   • action-server (Sema4.AI)                         │  │
│  │   • rcc (joshyorko fork)                             │  │
│  │   All binaries verified with SHA256 checksums        │  │
│  └──────────────────────────────────────────────────────┘  │
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
| **action-server** | Sema4.AI AI automation server |
| **rcc** | Robocorp/Sema4.AI automation runtime |

### On-Demand Brewfiles

Install additional tool bundles using the TUI:

```bash
ujust bbrew          # Interactive TUI to select Brewfiles
ujust brew-install-all  # Install everything
```

| Brewfile | Tools Included |
|----------|----------------|
| **cli** | bat, eza, fd, fzf, ripgrep, jq, yq, htop, tmux |
| **k8s** | kubectl, helm, k9s, k3d, skaffold, dagger, devspace |
| **cloud** | aws-cli, azure-cli, terraform |
| **security** | cosign, grype, syft, trivy |
| **data** | duckdb, sqlite, httpie |
| **dev** | gh, git-lfs, pre-commit |

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
- **glibc compatible**: Works with most Linux binaries

### Supply Chain Security
- **SBOM generation**: Every image includes a Software Bill of Materials
- **Cosign signatures**: All artifacts cryptographically signed
- **CVE scanning**: Critical vulnerabilities block releases
- **SHA256 verification**: Direct downloads in ror-specialty verified with checksums

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
│       ├── cli.Brewfile     # Terminal utilities
│       ├── k8s.Brewfile     # Kubernetes tools
│       ├── cloud.Brewfile   # Cloud provider CLIs
│       ├── security.Brewfile # Security scanning tools
│       ├── data.Brewfile    # Data tools
│       └── dev.Brewfile     # Git and development tools
├── src/                     # DevContainer Features source
│   └── ror-specialty/       # Non-Homebrew tools (Sema4.AI)
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

All tools are pre-installed: mise, starship, zoxide, nushell, action-server, rcc. Use `ujust bbrew` for additional Homebrew tools.

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

- Updates tool versions in `ror-specialty` with SHA256 checksum verification
- Tracks PyPI package versions for the maintenance robot itself
- Updates GitHub Actions workflow dependencies
- Regenerates devcontainer lockfiles

```bash
# Run full maintenance
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance
```

See [automation/maintenance-robot/README.md](automation/maintenance-robot/README.md) for details.

---

## 📊 Performance Targets

| Metric | Target |
|--------|--------|
| First pull startup | < 60 seconds (100Mbps) |
| Cached container start | < 15 seconds |
| Image size (compressed) | < 500MB |
| Starship prompt render | < 100ms |
| mise tool switch (cached) | < 500ms |

---

## 🏷️ Image Tags

| Tag | Description |
|-----|-------------|
| `latest` | Most recent build (daily updates) |
| `stable` | Monthly release (recommended for teams) |
| `v2.x.x` | Specific semantic version (pinned) |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following [.github/copilot-instructions.md](.github/copilot-instructions.md) guidelines
4. Test with `devcontainer build --workspace-folder .`
5. Submit a PR with conventional commit messages

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

## Why Room of Requirement?

> _"It is a room that a person can only enter when they have real need of it. Sometimes it is there, and sometimes it is not, but when it appears, it is always equipped for the seeker's needs."_

Because every developer deserves a workspace that adapts to their needs—just like magic. 🪄
