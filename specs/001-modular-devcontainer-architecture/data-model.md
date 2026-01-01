# Data Model: Modular DevContainer Architecture

**Feature**: 001-modular-devcontainer-architecture
**Date**: 2026-01-01

This document defines the key entities, their relationships, and state transitions for the Room of Requirement modular architecture.

---

## Entity Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        OCI Registry (GHCR)                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │   Features   │    │   Template   │    │ Pre-built    │          │
│  │   (OCI)      │    │   (OCI)      │    │ Image (OCI)  │          │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘          │
│         │                   │                   │                   │
│         └───────────────────┼───────────────────┘                   │
│                             │                                       │
│                    ┌────────▼────────┐                              │
│                    │    Attestations │                              │
│                    │  (SBOM, Sig)    │                              │
│                    └─────────────────┘                              │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      DevContainer Runtime                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │   Project    │───▶│  Container   │───▶│   Tools      │          │
│  │(.mise.toml + │    │  Instance    │    │(mise+brew)   │          │
│  │ Brewfile)    │    │              │    │              │          │
│  └──────────────┘    └──────────────┘    └──────────────┘          │
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐                              │
│  │   Homebrew   │───▶│  Package     │                              │
│  │ (/linuxbrew) │    │ Management   │                              │
│  └──────────────┘    └──────────────┘                              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Core Entities

### 1. DevContainer Feature

A discrete, versioned component packaged as an OCI artifact.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier (e.g., `mise`, `starship`) |
| `version` | semver | Yes | Semantic version (e.g., `1.0.0`) |
| `name` | string | Yes | Human-readable name |
| `description` | string | No | Feature description |
| `options` | object | No | Configurable installation options |
| `dependsOn` | object | No | Required features (for Meta-Features) |
| `installsAfter` | array | No | Soft ordering hints |

**Validation Rules**:
- `id` must be lowercase alphanumeric with hyphens
- `version` must follow semantic versioning
- `dependsOn` references must be valid GHCR URIs

**State Transitions**:
```
[Draft] ──publish──▶ [Published] ──deprecate──▶ [Deprecated]
                           │
                           └──patch──▶ [Published v+1]
```

#### Feature Types

| Type | Description | Example |
|------|-------------|---------|
| Atomic Feature | Single-purpose tool installer | `mise`, `starship` |
| Meta-Feature | Aggregates other features via `dependsOn` | `ror-core` |
| Optional Feature | Specialty tools not in base | `ror-specialty` |

---

### 2. DevContainer Template

A starter configuration for bootstrapping new projects.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Template identifier (e.g., `ror-starter`) |
| `version` | semver | Yes | Template version |
| `name` | string | Yes | Human-readable name |
| `description` | string | No | Template description |
| `options` | object | No | User-configurable options |

**Validation Rules**:
- Must include valid `devcontainer.json` in output
- Referenced Features must exist in registry

**State Transitions**:
```
[Draft] ──publish──▶ [Published] ──update──▶ [Published v+1]
```

---

### 3. Pre-built Image

The `ror:latest` OCI container image with all Features embedded.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `digest` | sha256 | Yes | Image content hash |
| `tags` | array | Yes | Version tags (`latest`, `stable`, `v1.0.0`) |
| `architecture` | string | Yes | CPU architecture (`amd64`) |
| `attestations` | object | Yes | SBOM and signature references |

**Tag Strategy**:
| Tag | Purpose | Update Frequency |
|-----|---------|------------------|
| `latest` | Bleeding edge | Every merge to main |
| `stable` | Monthly release | Monthly |
| `v{major}.{minor}.{patch}` | Pinned version | Immutable |
| `sha-{short}` | Git commit | Every build |

**Validation Rules**:
- Must pass CVE scan (no Critical with fix available)
- Must have valid Cosign signature
- Must have SBOM attestation

**State Transitions**:
```
[Building] ──scan-pass──▶ [Signed] ──publish──▶ [Published]
     │                                               │
     └──scan-fail──▶ [Rejected]                      └──new-build──▶ [Superseded]
```

---

### 4. Attestation

Cryptographic proof attached to an OCI artifact.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | enum | Yes | `signature`, `sbom`, `provenance` |
| `format` | string | Yes | `cosign`, `spdx-json`, `slsa-v1` |
| `digest` | sha256 | Yes | Attestation content hash |
| `issuer` | string | Yes | OIDC issuer URL |
| `identity` | string | Yes | Certificate identity |

**Attestation Types**:
| Type | Format | Purpose |
|------|--------|---------|
| Signature | Cosign | Verifies artifact authenticity |
| SBOM | SPDX JSON | Lists all dependencies |
| Provenance | SLSA v1 | Build metadata and inputs |

---

### 5. Tool Management

**Package Manager Strategy**: Wolfi (system) + Homebrew (CLI tools) + mise (language runtimes)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `manager` | enum | Yes | `wolfi`, `homebrew`, `mise` |
| `name` | string | Yes | Package/tool identifier |
| `version` | string | Yes | Installed version |
| `scope` | enum | Yes | `system`, `user`, `project` |
| `source` | string | Yes | Package source (apk, formula, plugin) |

**Package Manager Precedence**:
```
Wolfi (system deps) > Homebrew (CLI tools) > mise (language runtimes)
```

**Tool Categories**:
| Category | Manager | Examples | Rationale |
|----------|---------|----------|----------|
| System Dependencies | Wolfi | `git`, `curl`, `bash` | Security, minimal base |
| CLI Tools | Homebrew | `kubectl`, `helm`, `jq` | Vast ecosystem, latest versions |
| Language Runtimes | mise | `node`, `python`, `go` | Version switching required |

**State Transitions**:
```
[Not Installed] ──install──▶ [Installed] ──uninstall──▶ [Not Installed]
                                  │
                                  └──activate──▶ [Active]
```

---

### 6. Tool (Runtime Entity)

A language runtime or CLI tool managed by the hybrid package management system.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Tool identifier (e.g., `node`, `kubectl`) |
| `version` | string | Yes | Installed version |
| `manager` | enum | Yes | `wolfi`, `homebrew`, `mise` |
| `scope` | enum | Yes | `system`, `user`, `project` |
| `source` | string | Yes | Installation source (apk, formula, plugin) |

**Installation Strategy by Tool Type**:
```
# System Dependencies (Wolfi)
apk add git curl bash openssh ca-certificates

# CLI Tools (Homebrew)
brew install kubectl helm k9s jq yq gh

# Language Runtimes (mise)
mise install node@lts python@latest go@latest
```

**State Transitions**:
```
[Not Installed] ──package manager install──▶ [Installed] ──uninstall──▶ [Not Installed]
                                                   │
                                                   └──mise use──▶ [Active] (mise only)
```

**Pre-installed Tools** (in `ror:latest`):
| Tool | Manager | Version | Rationale |
|------|---------|---------|-----------|
| git | Wolfi | Latest | System dependency |
| curl | Wolfi | Latest | System dependency |
| node | mise | LTS (22.x) | JavaScript runtime |
| python | mise | Latest (3.12.x) | Python runtime |
| go | mise | Latest (1.22.x) | Go runtime |
| brew | Direct | Latest | Package manager itself |

**Homebrew Foundation**:
- Installed to `/home/linuxbrew/.linuxbrew/`
- `linuxbrew` user for proper permissions
- `/home/linuxbrew/.linuxbrew/bin` in system `$PATH`
- Compatible with Wolfi glibc base

---

### 7. Configuration File

User or system configuration affecting container behavior.

| File | Location | Purpose |
|------|----------|---------|
| `devcontainer.json` | `.devcontainer/` | Container definition |
| `.mise.toml` | Project root | Project-specific tool versions |
| `Brewfile` | Project root | Project-specific CLI tools |
| `starship.toml` | `~/.config/starship/` | Prompt configuration |
| `.zshrc` | `~/` | Shell initialization |

**Configuration Precedence**:
```
User dotfiles (injected) > Project config > Image defaults
```

**Project Hydration Workflow**:
```
1. Container starts with pre-installed base tools
2. postCreateCommand checks for .mise.toml -> mise install
3. postCreateCommand checks for Brewfile -> brew bundle install
4. Shell loads with mise shims + Homebrew PATH
```

**Brewfile Example**:
```ruby
# CLI Tools
brew "kubectl"
brew "helm"
brew "k9s"
brew "jq"
brew "yq"
brew "gh"

# Optional: Development tools
brew "docker-compose" if OS.linux?
brew "terraform"
```

---

## Relationships

```
┌─────────────────┐         ┌─────────────────┐
│   Meta-Feature  │────────▶│  Atomic Feature │
│   (ror-core)    │dependsOn│  (mise, etc.)   │
└─────────────────┘         └─────────────────┘
         │
         │ embeds
         ▼
┌─────────────────┐         ┌─────────────────┐
│  Pre-built      │◀────────│    Template     │
│  Image          │references│  (ror-starter) │
└─────────────────┘         └─────────────────┘
         │
         │ has
         ▼
┌─────────────────┐
│   Attestations  │
│ (sig, sbom)     │
└─────────────────┘
```

### Dependency Graph (ror-core Meta-Feature)

```
ror-core
├── mise (tool manager for languages)
│   └── installs: node, python, go
├── starship (prompt)
├── zoxide (directory navigation)
└── homebrew (CLI package manager)
    └── provides: brew command for project hydration
```

### Optional Features (not in ror-core)

```
ror-cli-tools (Homebrew-based)
├── kubectl, helm, k9s (via Brewfile generation)
├── kind, k3d (via Brewfile generation)
└── aws-cli, jq, yq (via Brewfile generation)

ror-specialty (Non-Homebrew tools)
├── rcc, action-server (Sema4.AI direct downloads)
├── dagger (direct binary)
├── container-use (direct binary)
└── Documentation recommends Brewfile alternatives where available
```

---

## Validation Rules Summary

### Feature Publishing
1. All options must have default values
2. `install.sh` must be POSIX-compatible
3. Must support Wolfi base image
4. Version must not already exist in registry

### Image Publishing
1. CVE scan must pass (no Critical with available fix)
2. Size must be <500MB compressed
3. Must include all attestations (sig, sbom, provenance)
4. Build must be reproducible

### Template Publishing
1. Must reference published Features only
2. `devcontainer.json` must be valid JSON
3. Must pass schema validation

---

## Security Constraints

| Constraint | Enforcement |
|------------|-------------|
| Non-root user | `remoteUser: vscode` in devcontainer.json |
| Signed artifacts | Cosign verification before pull |
| CVE remediation | <24h for Critical (Wolfi SLA) |
| No secrets in image | Build-time scanning |
| Trusted registries | GHCR only |
