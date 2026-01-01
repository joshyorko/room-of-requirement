# Implementation Plan: Modular DevContainer Architecture

**Branch**: `001-modular-devcontainer-architecture` | **Date**: 2026-01-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-modular-devcontainer-architecture/spec.md`

## Summary

Redesign the Room of Requirement DevContainer from a monolithic Ubuntu-based Dockerfile to a modular, security-first architecture using Wolfi OS as the base. The new architecture implements DevContainer Features for composability, integrates **Homebrew as a first-class package manager** alongside mise-en-place for language runtimes, and provides cryptographic supply chain security via Sigstore/Cosign signing and SBOM attestations.

The three-tier package management strategy prioritizes:
1. **Wolfi apk** for system dependencies (glibc, git, curl, bash)
2. **Homebrew** for CLI tools and development utilities (kubectl, helm, jq, gh)
3. **mise-en-place** for language runtimes requiring version switching (Node.js, Python, Go)

## Technical Context

**Language/Version**: Bash (install scripts), Python 3.12 (maintenance robot), Dockerfile (container definition)
**Primary Dependencies**: Wolfi OS (cgr.dev/chainguard/wolfi-base), Homebrew (Linuxbrew), mise-en-place, Starship, zoxide, @devcontainers/cli
**Storage**: OCI Registry (GHCR), local volumes for caching (Homebrew, mise, npm)
**Testing**: `devcontainer build`, `hadolint`, RCC maintenance tasks, Grype CVE scanning
**Target Platform**: Linux containers (amd64 only; arm64 deferred per FR-022), VS Code Remote Containers, DevPod, GitHub Codespaces
**Project Type**: Monorepo (Features, Templates, Images, Automation)
**Performance Goals**: <60s first pull (100Mbps), <15s subsequent starts, <500ms tool version switch, <100ms Starship prompt
**Constraints**: <500MB compressed image size, 0 Critical CVEs unfixed >24h, SLSA Level 3 provenance
**Scale/Scope**: Single pre-built image serving multiple developer personas via Brewfile hydration

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Check (✅ PASSED)

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Automation-First Maintenance** | ✅ PASS | RCC maintenance robot extended for new architecture; allowlists updated for Homebrew, Wolfi packages |
| **II. Reproducible Builds** | ✅ PASS | Pinned versions with SHA256 checksums; multi-stage Dockerfile preserved; lock file pattern maintained |
| **III. Security by Default** | ✅ PASS | Docker-in-Docker privileged mode permitted per constitution v1.1.0 Justified Exception; all 7 mitigations enforced |
| **IV. Conventional Commits** | ✅ PASS | Feature branch follows naming convention; commit structure maintained |
| **V. Validation Before Merge** | ✅ PASS | `test-devcontainer-build` task updated; hadolint linting enforced |

### Post-Design Re-Check (✅ PASSED)

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Automation-First Maintenance** | ✅ PASS | Homebrew Brewfile detection automated in postCreateCommand; maintenance robot updated |
| **II. Reproducible Builds** | ✅ PASS | Brewfile.lock.json pattern documented; volume caching for Homebrew cache |
| **III. Security by Default** | ✅ PASS | Per constitution v1.1.0 Justified Exception; mitigations (non-root user, Cosign signing, CVE scanning, SBOM attestations) in place |
| **IV. Conventional Commits** | ✅ PASS | Research, data-model, contracts use conventional structure |
| **V. Validation Before Merge** | ✅ PASS | Comprehensive testing workflow defined |

## Project Structure

### Documentation (this feature)

```text
specs/001-modular-devcontainer-architecture/
├── plan.md              # This file (implementation plan)
├── research.md          # ✅ Complete - Technical decisions and Homebrew patterns
├── data-model.md        # ✅ Complete - Entity definitions with Homebrew integration
├── quickstart.md        # ✅ Complete - User guide with Brewfile examples
├── contracts/           # ✅ Complete - API schemas
│   ├── build-workflow-inputs.yaml
│   ├── feature-manifest.schema.json
│   └── maintenance-allowlist.schema.json
├── checklists/
│   └── requirements.md  # Requirements verification checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
.devcontainer/
├── Dockerfile           # Multi-stage Wolfi + Homebrew + mise build
├── devcontainer.json    # Container configuration with Features
├── devcontainer-lock.json # Version pins and checksums
└── post-create.sh       # Brewfile + mise hydration script

features/
├── ror-core/            # Meta-Feature aggregating core tools
│   ├── devcontainer-feature.json
│   ├── install.sh
│   └── README.md
├── mise/                # Tool version manager
├── starship/            # Shell prompt
├── zoxide/              # Directory navigation
├── nushell/             # Alternative shell
├── ror-cli-tools/       # Homebrew-based CLI tools Feature
│   ├── devcontainer-feature.json
│   ├── install.sh
│   ├── Brewfile         # Default CLI tools bundle
│   └── README.md
└── ror-specialty/       # Non-Homebrew specialty tools

templates/
└── ror-starter/         # Starter template for new projects
    ├── .devcontainer/
    │   ├── devcontainer.json
    │   ├── Brewfile     # Example project Brewfile
    │   └── post-create.sh
    └── .mise.toml       # Example tool versions

automation/
└── maintenance-robot/
    ├── robot.yaml       # RCC task definitions (UPDATED: add update-homebrew task)
    ├── tasks.py         # Python automation (UPDATED: Homebrew support)
    ├── allowlists/
    │   ├── downloads.json      # UPDATED: Remove obsolete tools, add mise/starship/zoxide
    │   ├── github_actions.json # UPDATED: Add cosign, syft, grype, devcontainers/ci
    │   └── homebrew.json       # NEW: Homebrew formula allowlist (kubectl, helm, k9s, jq, yq, gh)
    └── src/
        └── maintenance_robot/
            ├── homebrew.py     # NEW: Homebrew version tracking via formulae.brew.sh API
            ├── reporter.py     # UPDATED: Include Homebrew in maintenance reports
            └── ...existing modules

.github/
└── workflows/
    ├── build-image.yml        # Image build with signing
    ├── build-features.yml     # Feature publishing
    └── rcc-maintenance.yml    # Daily maintenance
```

**Structure Decision**: Monorepo structure with Features as discrete OCI artifacts. Homebrew integrated at base image level with Brewfile hydration support for project customization.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Docker-in-Docker `--privileged` | Container nesting for inner Docker daemon | Rootless Docker not reliably supported across VS Code, DevPod, Kubernetes sidecars; documented path to rootless when ecosystem matures |
| Three-tier package management (Wolfi + Homebrew + mise) | Clear separation of system deps, CLI tools, and language runtimes | Single package manager insufficient: Wolfi lacks CLI tool breadth, mise only handles runtimes, Homebrew alone lacks security-focused base |

## Key Design Decisions

### Homebrew as First-Class Citizen

Homebrew integration provides:

1. **Universal Blue-Inspired Foundation**: Wolfi (security-focused base) + Homebrew (tool ecosystem) mirrors successful immutable desktop patterns
2. **Declarative Project Dependencies**: Brewfile pattern for per-project tool management
3. **glibc Compatibility**: Wolfi's glibc foundation enables native Homebrew bottles (no source compilation)
4. **Reduced Custom Scripts**: Homebrew formulae replace individual download/install scripts for ~80% of CLI tools

**PATH Precedence**:
```
1. mise shims     (/usr/local/share/mise/shims)    - Language runtimes
2. Homebrew       (/home/linuxbrew/.linuxbrew/bin) - CLI tools
3. Direct install (/usr/local/bin)                 - Specialty tools
4. System         (/usr/bin)                       - Base packages
```

**Hydration Workflow**:
```
Container Start
     ↓
postCreateCommand
     ↓
┌────────────────────────────────────────┐
│ 1. Detect Brewfile → brew bundle       │
│ 2. Detect .mise.toml → mise install    │
│ 3. Detect package.json → npm/pnpm      │
│ 4. Run mise setup task if defined      │
└────────────────────────────────────────┘
```

### Security Posture

- **Signed Artifacts**: All Features, Templates, and Images signed with Sigstore/Cosign
- **SBOM Attestations**: SPDX SBOMs attached to OCI artifacts
- **CVE Scanning**: Grype with fail-on-critical; Wolfi's <24h CVE response SLA
- **Non-root User**: `vscode` user for all container operations

## Phase Completion Status

| Phase | Status | Output |
|-------|--------|--------|
| Phase 0: Research | ✅ Complete | [research.md](research.md) |
| Phase 1: Design & Contracts | ✅ Complete | [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md) |
| Phase 2: Tasks | ✅ Complete | [tasks.md](tasks.md) - 121 tasks across 10 phases |

## Maintenance Automation Changes

The existing RCC maintenance robot requires significant updates for the new architecture:

### Obsolete Entries to Remove from downloads.json
The following tools are no longer direct binary downloads - they've moved to Homebrew or mise:
- **Removed**: kind, k3d, k9s, awscli, uv, duckdb, rcc, nodejs
- **Removed Features**: common-utils-feature, kubectl-helm-minikube-feature, github-cli-feature

### New Tools to Track in downloads.json
Direct binary downloads for the new Dockerfile:
- **mise** (jdx/mise) - polyglot runtime manager
- **starship** (starship/starship) - cross-shell prompt
- **zoxide** (ajeetdsouza/zoxide) - smart directory jumper

### Specialty Tools Target Update
Specialty tools now live in `features/ror-specialty/install.sh` instead of the Dockerfile:
- action-server, dagger, claude-code, container-use, devspace, hauler

### New Homebrew Source Type
New module to query Homebrew API for formula versions:
- **Tracked formulas**: kubectl, helm, k9s, jq, yq, gh, awscli
- **API endpoint**: `https://formulae.brew.sh/api/formula/{name}.json`

### GitHub Actions Updates
New actions for supply chain security workflows:
- sigstore/cosign-installer (image signing)
- anchore/sbom-action (Syft SBOM generation)
- anchore/scan-action (Grype CVE scanning)
- devcontainers/ci (Feature publishing)

See [tasks.md](tasks.md) Phase 9 (T088-T109) for complete implementation breakdown.

## Next Steps

1. ~~Run `/speckit.tasks` to generate implementation tasks from this plan~~ ✅ Complete
2. Execute tasks in dependency order, starting with Wolfi base image
3. Validate each Feature independently before Meta-Feature integration
4. Run full test suite including Homebrew bundle and mise hydration tests
5. **Phase 9**: Update maintenance robot after Features structure is complete (depends on US3)
