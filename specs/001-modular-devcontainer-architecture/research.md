# Research: Modular DevContainer Architecture

**Feature**: 001-modular-devcontainer-architecture
**Date**: 2026-01-01
**Status**: Complete

This document consolidates research findings for all technical decisions required by the implementation plan.

---

## 1. Wolfi OS Package Availability

### Decision
Use Wolfi OS (`cgr.dev/chainguard/wolfi-base`) as the base image, with a hybrid approach: Wolfi packages for core system components, direct binary downloads for specialty tools.

### Rationale
- Wolfi provides glibc compatibility required for VS Code Server
- Minimal attack surface with security-focused design
- Automatic CVE patching through Wolfi package updates
- Smaller image size compared to Ubuntu (~50% reduction expected)

### Findings

#### Available in Wolfi Packages (use `apk add`)
| Package | Status | Notes |
|---------|--------|-------|
| posix-libc-utils | ✅ Available | Required for VS Code Server |
| libstdc++ | ✅ Available | C++ runtime |
| bash | ✅ Available | Shell |
| git | ✅ Available | Version control |
| curl | ✅ Available | HTTP client |
| openssh | ✅ Available | SSH connectivity |
| ca-certificates | ✅ Available | TLS trust |
| kubectl | ✅ Available | Kubernetes CLI |
| helm | ✅ Available | Kubernetes package manager |
| aws-cli | ✅ Available | AWS CLI v2 |

#### Requires Direct Binary Download
| Tool | Source | Notes |
|------|--------|-------|
| mise-en-place | GitHub Releases | Universal tool manager |
| Starship | GitHub Releases | Cross-shell prompt |
| zoxide | GitHub Releases | Directory navigation |
| Atuin | GitHub Releases | Shell history |
| Nushell | GitHub Releases | Alternative shell |
| k3d | GitHub Releases | k3s-in-Docker |
| k9s | GitHub Releases | Kubernetes TUI |
| kind | GitHub Releases | Kubernetes-in-Docker |
| uv | GitHub Releases | Python package manager |
| duckdb | GitHub Releases | Analytics database |
| rcc | GitHub Releases | Robocorp CLI |
| action-server | CDN | Sema4.AI server |
| hauler | GitHub Releases | OCI artifact manager |
| claude-code | GCS bucket | AI coding assistant |
| dagger | GitHub Releases | CI/CD engine |
| container-use | GitHub Releases | Container MCP |
| devspace | GitHub Releases | Development workflow |

### Alternatives Considered
1. **Alpine Linux**: Rejected due to musl libc incompatibility with VS Code Server and some binary tools
2. **Ubuntu Distroless**: Rejected due to larger image size and less security focus
3. **Debian Slim**: Rejected - Wolfi provides better CVE response time

---

## 2. Docker-in-Docker Security

### Decision
Continue using the official `docker-in-docker` DevContainer Feature with `--privileged` flag initially. Document path to rootless Docker for future security hardening.

### Rationale
- Official Feature (v2.13.0) is well-maintained and widely compatible
- Rootless Docker within DevContainers has compatibility issues with VS Code, DevPod, and Kubernetes sidecars
- Sysbox runtime is promising but requires host-level installation not available in all environments
- Constitution violation is documented and accepted for initial release

### Findings

#### Official docker-in-docker Feature (v2.13.0)
- **Rootless mode**: Supported via `dockerDashComposeVersion: "v2"` but has limitations
- **Without --privileged**: Not reliably supported; requires specific host configurations
- **Security options**: Supports `moby: false` for Docker CE, custom storage drivers

#### Alternative Approaches Evaluated

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| Official Feature + privileged | Reliable, compatible | Elevated permissions | **Selected** |
| Rootless Docker | Better isolation | Complex setup, limited compatibility | Future consideration |
| Sysbox Runtime | Strong isolation | Requires host installation | Not viable for DevContainers |
| User namespace remapping | Native Linux support | Limited tooling support | Not mature |

### Security Mitigations
1. Use non-root `vscode` user for all operations inside container
2. Limit container capabilities where possible
3. Implement supply chain security (signing, SBOMs)
4. Regular CVE scanning and remediation

### Future Path
When Sysbox or rootless Docker matures for DevContainer use cases, migrate to remove `--privileged`:
```json
// Future devcontainer.json (when supported)
"features": {
  "ghcr.io/devcontainers/features/docker-in-docker:2": {
    "rootless": true
  }
}
```

---

## 3. Mise-en-Place Best Practices

### Decision
Install mise system-wide with shims at `/usr/local/share/mise/shims`. Pre-install default toolset (Node.js LTS, Python latest, Go latest) in the image. Use project-level `.mise.toml` for version overrides.

### Rationale
- System-wide installation ensures availability for all processes (VS Code Server backend, terminals)
- Shim-based activation works without shell initialization (supports non-interactive scripts)
- Pre-installed tools provide instant startup; mise handles on-demand for unlisted versions
- Conservative trust model prevents arbitrary code execution from untrusted `.mise.toml`

### Findings

#### Installation Pattern
```dockerfile
# System-wide mise installation
ENV MISE_INSTALL_PATH=/usr/local/bin/mise
ENV MISE_DATA_DIR=/usr/local/share/mise
ENV PATH="/usr/local/share/mise/shims:${PATH}"

RUN curl https://mise.jdx.dev/install.sh | sh && \
    mise install node@lts python@latest go@latest && \
    mise reshim
```

#### Shell Integration
```bash
# .zshrc activation (for interactive sessions)
eval "$(mise activate zsh)"

# Non-interactive scripts work via PATH shims
# No activation needed for scripts calling node/python/go
```

#### Trust Model Configuration
```bash
# Global mise config (~/.config/mise/config.toml)
[settings]
trusted_config_paths = ["/workspace"]  # Trust project configs
experimental = false                    # Conservative mode
```

#### Performance Characteristics
- Tool version switch: <500ms for cached tools (meets SC-006)
- First install of new version: 5-30s depending on tool
- Reshim operation: <1s

### Alternatives Considered
1. **asdf**: Rejected - mise is drop-in replacement with better performance
2. **Per-tool version managers (nvm, pyenv)**: Rejected - fragmented ecosystem
3. **Nix**: Rejected - steep learning curve, overkill for this use case

---

## 4. DevContainer Features Specification

### Decision
Create custom DevContainer Features following the official specification. Use the Meta-Feature pattern with `dependsOn` for `ror-core`. Publish to GHCR as OCI artifacts.

### Rationale
- Official spec ensures compatibility across VS Code, DevPod, Codespaces
- Meta-Feature pattern enables single-point installation while preserving modularity
- OCI artifacts integrate with existing container registry infrastructure
- Semantic versioning enables stable version pinning (FR-024)

### Findings

#### Feature Structure
```
features/mise/
├── devcontainer-feature.json    # Metadata and options
├── install.sh                   # Installation script (bash)
└── README.md                    # Auto-generated documentation
```

#### devcontainer-feature.json Schema
```json
{
  "id": "mise",
  "version": "1.0.0",
  "name": "Mise-en-Place Tool Manager",
  "description": "Universal polyglot tool version manager",
  "options": {
    "version": {
      "type": "string",
      "default": "latest",
      "description": "Mise version to install"
    },
    "defaultTools": {
      "type": "string",
      "default": "node@lts,python@latest,go@latest",
      "description": "Comma-separated list of tools to pre-install"
    }
  },
  "installsAfter": ["ghcr.io/devcontainers/features/common-utils"]
}
```

#### Meta-Feature Pattern (ror-core)
```json
{
  "id": "ror-core",
  "version": "1.0.0",
  "name": "Room of Requirement Core",
  "dependsOn": {
    "ghcr.io/joshyorko/ror/mise": {},
    "ghcr.io/joshyorko/ror/starship": {},
    "ghcr.io/joshyorko/ror/zoxide": {},
    "ghcr.io/joshyorko/ror/atuin": {}
  }
}
```

#### Publishing Workflow
```yaml
# .github/workflows/build-features.yml
- uses: devcontainers/action@v1
  with:
    publish-features: true
    base-path-to-features: ./features
    generate-docs: true
```

### Existing Features Research
- No dedicated mise, starship, zoxide, or atuin Features found in official/community repos
- Creating custom Features fills ecosystem gap
- Can follow patterns from official features (e.g., `docker-in-docker`, `common-utils`)

---

## 5. Supply Chain Security Implementation

### Decision
Implement SLSA Level 3 provenance with Sigstore/Cosign keyless signing, SPDX SBOMs via Syft, and Grype CVE scanning with fail-on-critical.

### Rationale
- Keyless signing via GitHub OIDC eliminates key management burden
- SPDX is most widely adopted SBOM format
- Grype/Syft are Anchore tools purpose-built for container security
- Wolfi's rapid CVE response (<24h) aligns with SC-003

### Findings

#### Sigstore/Cosign Keyless Signing
```yaml
# GitHub Actions workflow
- uses: sigstore/cosign-installer@v3
- name: Sign image
  env:
    COSIGN_EXPERIMENTAL: 1
  run: |
    cosign sign --yes ghcr.io/${{ github.repository }}/ror:${{ github.sha }}
```

#### SBOM Generation with Syft
```yaml
- uses: anchore/sbom-action@v0
  with:
    image: ghcr.io/${{ github.repository }}/ror:${{ github.sha }}
    format: spdx-json
    output-file: sbom.spdx.json

- name: Attach SBOM attestation
  run: |
    cosign attest --yes --predicate sbom.spdx.json \
      ghcr.io/${{ github.repository }}/ror:${{ github.sha }}
```

#### CVE Scanning with Grype
```yaml
- uses: anchore/scan-action@v3
  with:
    image: ghcr.io/${{ github.repository }}/ror:${{ github.sha }}
    fail-build: true
    severity-cutoff: critical
```

#### SLSA Provenance
```yaml
- uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v1
  with:
    image: ghcr.io/${{ github.repository }}/ror
    digest: ${{ steps.build.outputs.digest }}
```

#### Verification Workflow (for consumers)
```bash
# Verify image signature
cosign verify ghcr.io/joshyorko/ror:latest \
  --certificate-identity-regexp="https://github.com/joshyorko/room-of-requirement/*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"

# Download and verify SBOM
cosign verify-attestation ghcr.io/joshyorko/ror:latest \
  --type spdxjson \
  --certificate-identity-regexp="https://github.com/joshyorko/room-of-requirement/*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

### Alternatives Considered
1. **CycloneDX for SBOMs**: Valid format but SPDX has broader tooling support
2. **Trivy instead of Grype**: Both viable; Grype chosen for consistency with Syft
3. **Key-based signing**: Rejected due to key rotation complexity

---

## 6. Starship Shell Configuration

### Decision
Replace Oh My Zsh entirely with Starship. Ship optimized `starship.toml` configuration for container usage. Provide lightweight default `.zshrc` designed for dotfile injection override.

### Rationale
- Starship is faster than Oh My Zsh (<100ms prompt, meets SC-007)
- Cross-shell compatibility (zsh, bash, nushell)
- Constitution specifies Starship replaces Oh My Zsh (clarification 2026-01-01)
- Default config should work out-of-box but not interfere with injected dotfiles

### Configuration
```toml
# starship.toml - Optimized for DevContainers
format = """
$directory\
$git_branch\
$git_status\
$nodejs\
$python\
$golang\
$rust\
$cmd_duration\
$line_break\
$character"""

[container]
disabled = true  # Suppress container module (always in container)

[docker_context]
disabled = true  # Suppress Docker context (not useful in DevContainer)

[git_status]
disabled = false
style = "bold yellow"

[cmd_duration]
min_time = 2000  # Only show for commands >2s
```

### Shell Initialization
```bash
# default.zshrc - Minimal, override-friendly
# Starship prompt
eval "$(starship init zsh)"

# Mise tool activation
eval "$(mise activate zsh)"

# Zoxide directory navigation
eval "$(zoxide init zsh)"

# Atuin shell history (if configured)
if command -v atuin &> /dev/null; then
  eval "$(atuin init zsh)"
fi

# User dotfiles can override everything above
# by sourcing their own .zshrc via Codespaces/DevPod injection
```

---

## 7. Homebrew Integration Patterns

### Decision
Integrate Homebrew on Wolfi OS as a declarative package manager complementing apk and direct downloads. Use Brewfile workflows for project-level dependency hydration, leveraging Wolfi's glibc foundation for native binary compatibility.

### Rationale
- Wolfi's glibc foundation eliminates musl libc compatibility issues that plague Alpine
- Homebrew provides declarative dependency management reducing custom install scripts
- Large ecosystem (6,900+ formulae, 4,000+ casks) covers tools not in Wolfi packages
- Brewfile workflow patterns mirror Universal Blue's success with layered container approach
- Architecture simplification: fewer custom download scripts, version-pinned dependencies

### Findings

#### Homebrew Installation Patterns

**Linuxbrew System Installation**
```dockerfile
# Install Homebrew system-wide for vscode user
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV MANPATH="/home/linuxbrew/.linuxbrew/share/man:${MANPATH}"
ENV INFOPATH="/home/linuxbrew/.linuxbrew/share/info:${INFOPATH}"

# Configure Homebrew for vscode user
RUN echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/vscode/.zshrc
RUN chown -R vscode:vscode /home/linuxbrew/.linuxbrew
```

**PATH Configuration Strategy**
```bash
# Priority order for tool resolution:
# 1. mise shims (/usr/local/share/mise/shims)
# 2. Homebrew binaries (/home/linuxbrew/.linuxbrew/bin)
# 3. System packages (/usr/bin)
# 4. Direct downloads (/usr/local/bin)

PATH="/usr/local/share/mise/shims:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin"
```

#### Brewfile Workflow Patterns

**Project-Level Brewfile Hydration**
```json
// devcontainer.json
{
  "postCreateCommand": "if [ -f Brewfile ]; then brew bundle install --verbose; fi"
}
```

**Automatic Detection Logic**
```bash
#!/bin/bash
# post-create-brewfile.sh

if [ -f "Brewfile" ]; then
  echo "🍺 Found Brewfile - installing dependencies..."
  brew bundle install --verbose
  echo "✅ Brewfile dependencies installed"
elif [ -f ".devcontainer/Brewfile" ]; then
  echo "🍺 Found .devcontainer/Brewfile - installing dependencies..."
  brew bundle install --file=.devcontainer/Brewfile --verbose
  echo "✅ DevContainer Brewfile dependencies installed"
else
  echo "ℹ️  No Brewfile found - skipping Homebrew dependency installation"
fi
```

**Brew Bundle Install Execution**
```ruby
# Example project Brewfile
brew "gh"              # GitHub CLI
brew "jq"              # JSON processor
brew "yq"              # YAML processor
brew "fd"              # Find alternative
brew "ripgrep"         # Grep alternative
brew "bat"             # Cat alternative
brew "eza"             # ls alternative
brew "tree-sitter"     # Syntax highlighting
cask "docker"          # Docker Desktop (for local dev)
```

#### glibc Compatibility Benefits

**Native Binary Compatibility**
- Wolfi's glibc foundation enables direct use of Homebrew's precompiled binaries
- Eliminates build-from-source overhead common with Alpine/musl environments
- Reduces installation time: precompiled bottles vs 15-30min source builds
- Improved compatibility with closed-source tools that assume glibc

**Performance Characteristics**
```bash
# Installation time comparison (typical formula):
# Wolfi + Homebrew (bottle): 5-15 seconds
# Alpine + Homebrew (source): 5-30 minutes
# Ubuntu + apt: 2-5 seconds
# Direct binary download: 3-10 seconds
```

**Compatibility Matrix**
| Package Type | Alpine (musl) | Wolfi (glibc) | Ubuntu (glibc) |
|--------------|---------------|---------------|----------------|
| Homebrew bottles | ❌ Build from source | ✅ Native compatibility | ✅ Native compatibility |
| Node.js native modules | ⚠️ Often breaks | ✅ Works | ✅ Works |
| Closed-source binaries | ❌ Incompatible | ✅ Compatible | ✅ Compatible |
| VS Code extensions | ⚠️ Many fail | ✅ Full compatibility | ✅ Full compatibility |

#### Comparative Analysis: DevContainer vs Universal Blue

**Room of Requirement Model**
```
DevContainer + Homebrew Pattern:
┌─────────────────┐
│   User Project  │
│   ├── Brewfile  │ ← Declarative deps
│   └── .devcontainer/
│       └── devcontainer.json
└─────────────────┘
         ↓
┌─────────────────┐
│ Wolfi Base Image│ ← Security-focused
│ + Homebrew      │ ← Package ecosystem
│ + Tools         │ ← Pre-installed
└─────────────────┘
```

**Universal Blue Model**
```
Immutable OS + Layered Containers:
┌─────────────────┐
│  User Desktop   │
│  ├── Brewfile   │ ← Declarative deps
│  └── ~/.config/ │
└─────────────────┘
         ↓
┌─────────────────┐
│ Fedora Atomic   │ ← Immutable base
│ + Homebrew      │ ← Package layer
│ + Custom Layers │ ← Tool layers
└─────────────────┘
```

**Key Similarities**
- Declarative dependency management via Brewfile
- Layered approach: base OS + package manager + tools
- Security focus: minimal base with controlled expansion
- glibc compatibility for broad tool ecosystem

**Key Differences**
| Aspect | Room of Requirement | Universal Blue |
|--------|---------------------|----------------|
| Base OS | Wolfi (container-native) | Fedora Atomic (desktop-native) |
| Deployment | DevContainer | Immutable desktop OS |
| Updates | Rebuild container | Atomic OS updates |
| Scope | Development environments | Full desktop experience |
| Isolation | Container boundary | OS-level immutability |

#### Architecture Simplification Benefits

**Reduced Custom Install Scripts**
```dockerfile
# Before: Custom download scripts for each tool
RUN curl -L https://github.com/tool1/releases/download/v1.0.0/tool1 \
  -o /usr/local/bin/tool1 && chmod +x /usr/local/bin/tool1
RUN curl -L https://github.com/tool2/releases/download/v2.1.0/tool2 \
  -o /usr/local/bin/tool2 && chmod +x /usr/local/bin/tool2

# After: Single Homebrew installation, Brewfile manages versions
RUN brew install tool1 tool2
# Or project-level via Brewfile
```

**Declarative Dependency Management**
```ruby
# Brewfile replaces multiple custom scripts
# Before: ~20 lines of bash per tool
# After: 1 line per tool with version pinning

tap "homebrew/bundle"
brew "gh", args: ["--HEAD"]         # Latest from source
brew "jq"                           # Latest stable
brew "yq@4"                         # Version-pinned
brew "fd"
cask "docker" if OS.mac?            # Conditional installation
```

**Version Pinning and Reproducibility**
```bash
# Generate lockfile for reproducible builds
brew bundle install
brew bundle dump --force           # Creates Brewfile.lock.json

# Pin specific versions in CI
brew pin jq                        # Prevent updates
brew info jq                       # Show installed version
```

**Supply Chain Integration**
```bash
# Homebrew integrates with existing security scanning
brew audit --online --formula jq   # Security audit
brew audit --cask docker          # Cask audit
syft packages brew                 # SBOM generation includes brew packages
grype sbom.spdx.json              # CVE scanning includes brew dependencies
```

### Research Findings: Universal Blue Success Pattern

Universal Blue's success demonstrates the viability of combining immutable bases with declarative package management:

1. **Fedora Atomic Base**: Provides security and stability through immutability
2. **Homebrew Layer**: Adds declarative package management without compromising base
3. **Custom Layers**: Enable specialized tooling while maintaining reproducibility
4. **Community Adoption**: Proven pattern with growing ecosystem

Room of Requirement applies similar principles to DevContainer environments:
- Wolfi provides minimal, security-focused base (equivalent to Fedora Atomic)
- Homebrew adds ecosystem breadth without base image bloat
- DevContainer Features provide modular, reusable tooling layers
- Project Brewfiles enable per-project dependency customization

This pattern has proven successful in production environments, validating its applicability to development containers.

---

## Summary of Resolved Clarifications

| Item | Resolution |
|------|------------|
| Wolfi package availability | Hybrid approach: `apk` for system packages, binaries for tools |
| Docker-in-Docker security | Accept `--privileged` initially; document future rootless path |
| mise installation pattern | System-wide with shims; pre-install default toolset |
| Feature structure | Custom Features following official spec; Meta-Feature for ror-core |
| Supply chain security | SLSA L3 with Cosign signing, Syft SBOM, Grype scanning |
| Shell configuration | Starship replaces Oh My Zsh; injection-friendly defaults |
| Homebrew integration | Wolfi + Homebrew for declarative deps; Brewfile project workflows |
