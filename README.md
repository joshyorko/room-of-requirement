[![Open in DevPod!](https://devpod.sh/assets/open-in-devpod.svg)](https://devpod.sh/open#https://github.com/joshyorko/room-of-requirement)

# Room of Requirement 🧙

> _A modular, secure, bleeding-edge DevContainer platform built on Wolfi OS_

**Instant startup. Polyglot tooling. Supply chain security. Composable features.**

---

## 🚀 Quick Start

### Option 1: Use the Pre-built Image (Recommended)

Add to your project's `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/joshyorko/ror:latest",
  "features": {
    "ghcr.io/joshyorko/devcontainer-features/ror-core:1": {},
    "ghcr.io/joshyorko/devcontainer-features/ror-cli-tools:1": {},
    "ghcr.io/joshyorko/devcontainer-features/wolfi-docker-dind:1": {}
  }
}
```

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
│  │  Homebrew Foundation                                    ││
│  │  • Pre-installed for instant Brewfile hydration        ││
│  │  • /home/linuxbrew/.linuxbrew in PATH                  ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              DevContainer Features (Composable)             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐│
│  │   ror-core   │ │ ror-cli-tools│ │    ror-specialty     ││
│  │  (Meta)      │ │  (Homebrew)  │ │    (Direct DL)       ││
│  │  • mise      │ │  • kubectl   │ │  • action-server     ││
│  │  • starship  │ │  • helm      │ │  • rcc               ││
│  │  • zoxide    │ │  • k9s, jq   │ │  • dagger            ││
│  │              │ │  • gh, aws   │ │  • container-use     ││
│  └──────────────┘ └──────────────┘ └──────────────────────┘│
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐│
│  │    mise      │ │   starship   │ │  wolfi-docker-dind   ││
│  │  Polyglot    │ │   Prompt     │ │  Docker-in-Docker    ││
│  │  • Node LTS  │ │  • Git info  │ │  • Secure rootless   ││
│  │  • Python    │ │  • Tool ver  │ │  • No --privileged   ││
│  │  • Go        │ │  • Fast <100ms│ │                      ││
│  └──────────────┘ └──────────────┘ └──────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## 🧩 DevContainer Features

### Core Features

| Feature | Description | Registry |
|---------|-------------|----------|
| **ror-core** | Meta-feature: mise + starship + zoxide | `ghcr.io/joshyorko/devcontainer-features/ror-core:1` |
| **mise** | Polyglot version manager (Node, Python, Go, etc.) | `ghcr.io/joshyorko/devcontainer-features/mise:1` |
| **starship** | Cross-shell prompt with git/tool status | `ghcr.io/joshyorko/devcontainer-features/starship:1` |
| **zoxide** | Smart directory navigation (`z` command) | `ghcr.io/joshyorko/devcontainer-features/zoxide:1` |

### Tool Features

| Feature | Description | Registry |
|---------|-------------|----------|
| **ror-cli-tools** | Homebrew bundle: kubectl, helm, k9s, jq, yq, gh, aws-cli, terraform, ripgrep, fzf, bat, eza, cosign, grype, syft | `ghcr.io/joshyorko/devcontainer-features/ror-cli-tools:1` |
| **ror-specialty** | Sema4.AI (action-server, rcc), Dagger, container-use | `ghcr.io/joshyorko/devcontainer-features/ror-specialty:1` |
| **nushell** | Modern shell alternative | `ghcr.io/joshyorko/devcontainer-features/nushell:1` |

### Infrastructure Features

| Feature | Description | Registry |
|---------|-------------|----------|
| **wolfi-docker-dind** | Docker-in-Docker for Wolfi OS (secure, rootless) | `ghcr.io/joshyorko/devcontainer-features/wolfi-docker-dind:1` |

---

## 🛠️ Tool Management with mise

Room of Requirement uses [mise-en-place](https://mise.jdx.dev/) for polyglot version management:

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

## 📋 CLI Tools via Homebrew

The `ror-cli-tools` feature installs a curated bundle via Homebrew. Override by adding your own `Brewfile` to your project root:

```ruby
# Your project's Brewfile
brew "kubectl"
brew "helm"
brew "your-custom-tool"
```

### Default Tools Included

**Cloud & Kubernetes**: kubectl, helm, k9s, aws-cli, azure-cli, terraform, skaffold
**Development**: jq, yq, ripgrep, fd, fzf, bat, eza, httpie, sqlite, duckdb
**Git**: gh, git-lfs
**Security**: cosign, grype, syft
**System**: htop, tmux, tree, tldr

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
- **SHA256 verification**: Direct downloads verified with checksums

### Rootless Docker
- Docker-in-Docker runs without `--privileged` flag
- Follows principle of least privilege

---

## 🏗️ Repository Structure

```
room-of-requirement/
├── .devcontainer/           # DevContainer configuration for this repo
│   ├── devcontainer.json    # Feature references
│   ├── Dockerfile           # Wolfi OS base image
│   └── post-create.sh       # Post-creation hooks
├── src/                     # DevContainer Features source
│   ├── mise/                # Polyglot version manager
│   ├── starship/            # Cross-shell prompt
│   ├── zoxide/              # Smart directory navigation
│   ├── nushell/             # Modern shell
│   ├── ror-core/            # Meta-feature aggregator
│   ├── ror-cli-tools/       # Homebrew CLI bundle
│   ├── ror-specialty/       # Sema4.AI, Dagger tools
│   └── wolfi-docker-dind/   # Docker-in-Docker for Wolfi
├── templates/               # Project starter templates
│   └── ror-starter/         # Basic RoR template
├── automation/              # Maintenance automation
│   └── maintenance-robot/   # RCC-powered updater
└── specs/                   # Architecture specifications
```

---

## 🎛️ Customization Examples

### Minimal Setup (Just Tools)

```json
{
  "image": "ghcr.io/joshyorko/ror:latest",
  "features": {
    "ghcr.io/joshyorko/devcontainer-features/ror-core:1": {}
  }
}
```

### Full Cloud-Native Setup

```json
{
  "image": "ghcr.io/joshyorko/ror:latest",
  "features": {
    "ghcr.io/joshyorko/devcontainer-features/ror-core:1": {},
    "ghcr.io/joshyorko/devcontainer-features/ror-cli-tools:1": {},
    "ghcr.io/joshyorko/devcontainer-features/ror-specialty:1": {
      "installDagger": true,
      "installContainerUse": true
    },
    "ghcr.io/joshyorko/devcontainer-features/wolfi-docker-dind:1": {}
  }
}
```

### AI/Automation Development

```json
{
  "image": "ghcr.io/joshyorko/ror:latest",
  "features": {
    "ghcr.io/joshyorko/devcontainer-features/ror-core:1": {},
    "ghcr.io/joshyorko/devcontainer-features/ror-specialty:1": {
      "installActionServer": true,
      "installRcc": true
    }
  }
}
```

---

## 🔄 Automated Maintenance

The repository includes an RCC-powered maintenance robot that:

- Updates tool versions with SHA256 checksum verification
- Tracks Homebrew formula versions
- Updates GitHub Actions workflow dependencies
- Generates maintenance reports

```bash
# Run full maintenance
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance

# Test devcontainer build
rcc run -r automation/maintenance-robot/robot.yaml -t test-devcontainer-build
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
3. Make changes following [AGENTS.md](AGENTS.md) guidelines
4. Test with `rcc run -r automation/maintenance-robot/robot.yaml -t test-devcontainer-build`
5. Submit a PR with conventional commit messages

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

## Why Room of Requirement?

> _"It is a room that a person can only enter when they have real need of it. Sometimes it is there, and sometimes it is not, but when it appears, it is always equipped for the seeker's needs."_

Because every developer deserves a workspace that adapts to their needs—just like magic. 🪄
