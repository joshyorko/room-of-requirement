# Room of Requirement - AI Agent Guidelines

## Project Overview

A modular DevContainer platform built on Wolfi OS with **Homebrew as the first-class package manager**. Most tools are installed via curated Brewfiles rather than custom DevContainer Features.

**Architecture**: Wolfi OS (system deps) → Homebrew (CLI tools + language runtimes via mise)

## Repository Structure

```
.devcontainer/          # Container definition
  ├── Dockerfile        # Wolfi OS + Homebrew base
  ├── brew/             # Curated Brewfiles (core, cli, k8s, cloud, security, data, dev)
  ├── justfile          # ujust commands
  └── post-create.sh    # Hydration script
automation/maintenance-robot/  # RCC automation for dependency updates
src/ror-specialty/      # ONLY feature - tools NOT in Homebrew (Sema4.AI)
templates/ror-starter/  # Starter template
specs/                  # Feature specifications (SpecKit workflow)
```

## Homebrew-First Philosophy

**Prefer Homebrew over custom Features.** Only use `src/ror-specialty/` for tools that:
1. Are NOT available in Homebrew
2. Require SHA256 checksum verification for security

Tools like dagger, container-use, kubectl, etc. are now in Brewfiles, not Features.

### Pre-installed (core.Brewfile, baked into image)
- mise, starship, zoxide, nushell

### On-demand Brewfiles (.devcontainer/brew/)
- `cli.Brewfile` - bat, eza, fzf, ripgrep, jq, yq
- `k8s.Brewfile` - kubectl, helm, k9s, dagger, devspace
- `cloud.Brewfile` - aws-cli, azure-cli, terraform
- `security.Brewfile` - cosign, grype, syft, trivy
- `data.Brewfile` - duckdb, sqlite, httpie

## Key Patterns

### ror-specialty Feature (src/ror-specialty/)
The ONLY custom Feature - for tools not in Homebrew. Each tool requires:
- `devcontainer-feature.json` - manifest with options
- `install.sh` - installation with **mandatory SHA256 checksum verification**

**Example pattern** from [src/ror-specialty/install.sh](src/ror-specialty/install.sh):
```bash
# All direct downloads MUST include checksum verification
download_and_verify "$url" "$dest" "$sha256"
```

### Adding New Tools

**If available in Homebrew**: Add to appropriate Brewfile in `.devcontainer/brew/`

**If NOT in Homebrew**: Add to `src/ror-specialty/install.sh` with:
1. Version and SHA256 checksum variables
2. Allowlist entry in `automation/maintenance-robot/allowlists/downloads.json`

### Maintenance Robot (Automated Dependency Updates)
The Python-based maintenance robot in `automation/maintenance-robot/` automatically updates:
- **ror-specialty tools** - versions + SHA256 checksums (via `downloads.json`)
- **PyPI packages** - for the maintenance robot itself (via `downloads.json`)
- **GitHub Actions** - workflow `uses:` references (via `github_actions.json`)
- **Devcontainer lockfile** - feature digest pinning

**Note**: Homebrew tools are NOT auto-updated. They're managed via curated Brewfiles.

**Run locally:**
```bash
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance
```

### Version Pinning Convention
Tool versions in `src/ror-specialty/install.sh` are pinned with checksums:
```bash
RCC_VERSION="18.12.1"
RCC_SHA256="ec11807a08b23a098959a717e8011bcb776c56c2f0eaeded80b5a7dc0cb0da3a"
```
The maintenance robot updates these via regex patterns defined in allowlists.

## Developer Workflows

### Building the DevContainer
```bash
# Test build locally
devcontainer build --workspace-folder .

# Lint Dockerfile
hadolint .devcontainer/Dockerfile
```

### Running Maintenance Tasks
```bash
# Full maintenance run
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance

# Individual targets
rcc run -r automation/maintenance-robot/robot.yaml -t update-workflows
rcc run -r automation/maintenance-robot/robot.yaml -t update-downloads
rcc run -r automation/maintenance-robot/robot.yaml -t update-lockfile
```

### Homebrew Tools (via ujust)
```bash
ujust bbrew          # TUI to select and install from curated Brewfiles
ujust brew-install-all  # Install all packages from all Brewfiles
```

## Commit Convention

Uses conventional commits with release-please automation:
- `feat:` → ✨ Features (triggers minor version)
- `fix:` → 🐛 Bug Fixes (triggers patch)
- `security:` → 🔒 Security
- `deps:` → 📦 Dependencies

## CI/CD Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `build-image.yml` | Push to main (.devcontainer/**), workflow_run after Build Features | Build and push DevContainer image to GHCR |
| `build-features.yml` | Push to main (src/**) | Build and publish DevContainer Features |
| `rcc-maintenance.yml` | Daily cron + dispatch | Auto-update pinned versions via allowlists |
| `release.yml` | Push to main | Release-please automation for semantic versioning |

## Adding New Specialty Tools

1. Add version/checksum to [src/ror-specialty/install.sh](src/ror-specialty/install.sh)
2. Add allowlist entry to [automation/maintenance-robot/allowlists/downloads.json](automation/maintenance-robot/allowlists/downloads.json) with:
   - `repo` or `source` (github/pypi/npm)
   - `download_url_template`
   - `targets[].file` and `targets[].patterns` (regex with named group `(?P<version>...)`)
   - `targets[].sha256_pattern` for checksum fields

## SpecKit Workflow

Feature development follows the SpecKit pattern in `specs/`:
1. `spec.md` - User stories and requirements
2. `plan.md` - Implementation plan with constitution checks
3. `tasks.md` - Actionable task breakdown
4. Supporting docs: `research.md`, `data-model.md`, `contracts/`

Use the speckit agents (`@speckit.specify`, `@speckit.plan`, `@speckit.tasks`) for structured feature development.
