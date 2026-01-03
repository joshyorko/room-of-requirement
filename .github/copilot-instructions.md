# Room of Requirement - AI Agent Guidelines

## Project Overview

A modular DevContainer platform built on Wolfi OS with **Homebrew as the first-class package manager**. All tools are installed via curated Brewfiles.

**Architecture**: Wolfi OS (system deps) → Homebrew (CLI tools + language runtimes via mise)

## Repository Structure

```
.devcontainer/          # Container definition
  ├── Dockerfile        # Wolfi OS + Homebrew base
  ├── brew/             # Curated Brewfiles (core, cli, k8s, cloud, security, data, dev, ror)
  ├── justfile          # ujust commands
  └── post-create.sh    # Hydration script
automation/maintenance-robot/  # RCC automation for dependency updates
templates/ror-starter/  # Starter template
specs/                  # Feature specifications (SpecKit workflow)
```

## Homebrew-First Philosophy

**All tools are installed via Homebrew.** Tools like rcc, dagger, kubectl, etc. are in Brewfiles.

### Pre-installed (baked into image)
- mise, starship, zoxide, nushell

### On-demand Brewfiles (.devcontainer/brew/)
- `cli.Brewfile` - bat, eza, fzf, ripgrep, jq, yq
- `k8s.Brewfile` - kubectl, helm, k9s, dagger, devspace
- `cloud.Brewfile` - aws-cli, azure-cli, terraform
- `security.Brewfile` - cosign, grype, syft, trivy
- `data.Brewfile` - duckdb, sqlite, httpie
- `ror.Brewfile` - rcc (from joshyorko/tools tap), uv, gh

### Adding New Tools

Add to the appropriate Brewfile in `.devcontainer/brew/`. For tools with custom taps:
```ruby
tap "owner/repo"
brew "formula"  # or cask "formula"
```

### Maintenance Robot (Automated Dependency Updates)
The Python-based maintenance robot in `automation/maintenance-robot/` automatically updates:
- **PyPI packages** - for the maintenance robot itself (via `downloads.json`)
- **GitHub Actions** - workflow `uses:` references (via `github_actions.json`)
- **Homebrew versions** - tracks formula versions (via `homebrew.json`)

**Run locally:**
```bash
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance
```

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
rcc run -r automation/maintenance-robot/robot.yaml -t update-homebrew
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
| `build-image.yml` | Push to main (.devcontainer/**) | Build and push DevContainer image to GHCR |
| `rcc-maintenance.yml` | Daily cron + dispatch | Auto-update pinned versions via allowlists |
| `release.yml` | Push to main | Release-please automation for semantic versioning |

## SpecKit Workflow

Feature development follows the SpecKit pattern in `specs/`:
1. `spec.md` - User stories and requirements
2. `plan.md` - Implementation plan with constitution checks
3. `tasks.md` - Actionable task breakdown
4. Supporting docs: `research.md`, `data-model.md`, `contracts/`

Use the speckit agents (`@speckit.specify`, `@speckit.plan`, `@speckit.tasks`) for structured feature development.
