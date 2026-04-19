# Maintenance Robot

Automated upkeep for the Room of Requirement repository leveraging `rcc` and Robocorp tasks.

## Overview

This robot keeps the repository fresh by automating version updates for:

1. **GitHub Actions workflows** - Updates `uses:` references based on allowlisted actions
2. **External download pins** - Updates pinned versions and digests from sources like PyPI and Docker Hub
3. **Pre-commit hook repos** - Refreshes configured hook revisions in `.pre-commit-config.yaml`
4. **Homebrew tracking** - Logs formula versions (informational only)
5. **Curated Brewfile validation** - Catches renamed formulas or missing taps before post-create hydration breaks

### What This Robot Does NOT Update

**Homebrew packages are NOT auto-updated.** With our Homebrew-first architecture:
- Shell essentials (`mise`, `starship`, `zoxide`) are baked into the image
- Curated Brewfiles, including `bbrew`, are hydrated during DevContainer post-create
- On-demand tools are installed via curated Brewfiles in `.devcontainer/brew/`
- Homebrew handles versioning naturally via `brew update && brew upgrade`
- The `homebrew.json` allowlist is informational only - it logs versions but doesn't modify files

## Repository Layout

```
automation/maintenance-robot/
├── allowlists/
│   ├── downloads.json          # external download pins (with regex patterns)
│   ├── github_actions.json     # allowlisted GitHub Actions + version constraints
│   └── homebrew.json           # core Homebrew tools (informational/logging only)
├── conda.yaml                  # execution environment (Python 3.13 + uv + robocorp)
├── robot.yaml                  # robot definition consumed by rcc
├── src/maintenance_robot/
│   ├── __init__.py
│   ├── allowlist_loader.py
│   ├── devcontainer_lock.py
│   ├── downloads.py
│   ├── github_actions.py
│   ├── github_api.py
│   ├── homebrew.py
│   ├── npm_api.py
│   ├── pypi_api.py
│   ├── reporter.py
│   └── tasks.py
└── README.md
```

Generated artefacts (for example `output/maintenance_report.json`) are ignored via `.gitignore`.

## Running Locally

1. Ensure `rcc` is available (install via `brew install --cask joshyorko/tools/rcc`).
2. Pre-build/resolve the holotree environment:

```shell
rcc ht vars -r automation/maintenance-robot/robot.yaml --json
```

3. Run the maintenance task from the repository root:

```shell
rcc run -r automation/maintenance-robot/robot.yaml --task maintenance --silent
```

The robot prefers freeze artifacts from `output/environment_*_freeze.yaml` when present and falls back to `conda.yaml`.

### Available Tasks

| Task | Command | Description |
|------|---------|-------------|
| **maintenance** | `--task maintenance` | Full maintenance run (recommended) |
| **update-workflows** | `--task update-workflows` | Update GitHub Actions only |
| **update-downloads** | `--task update-downloads` | Update external download pins only |
| **update-lockfile** | `--task update-lockfile` | Regenerate devcontainer-lock.json only |
| **update-homebrew** | `--task update-homebrew` | Log Homebrew versions (informational only) |
| **validate-brewfiles** | `--task validate-brewfiles` | Validate curated Brewfiles resolve through Homebrew |
| **test-devcontainer** | `--task test-devcontainer` | Test devcontainer build |

To inspect the resolved environment without running the robot:

```shell
rcc ht vars -r automation/maintenance-robot/robot.yaml --json
```

A summary of changes is written to `automation/maintenance-robot/output/maintenance_report.json`.

## Allowlist Strategy

### downloads.json

Targets files for version and digest updates:
- **PyPI packages**: Fetch latest version for Python dependencies
- **Docker Hub images**: Fetch latest matching tag and refresh pinned digests
- Uses regex patterns with named groups: `(?P<version>...)`

Example entry:
```json
{
  "requests": {
    "source": "pypi",
    "package": "requests",
    "max_major": null,
    "include_prerelease": false,
    "targets": [{
      "file": "automation/maintenance-robot/conda.yaml",
      "patterns": ["requests==(?P<version>[0-9]+\\.[0-9]+\\.[0-9]+)"]
    }]
  }
}
```

### github_actions.json

Constrains GitHub Actions updates by:
- `max_major`: Maximum major version allowed (prevents breaking changes)
- `source`: `release` or `tag`
- `include_prerelease`: Whether to include pre-release versions

### homebrew.json

**Informational only** - tracks versions of core tools we rely on across the image and post-create hydration flow.
No file updates are performed. This is useful for:
- Monitoring what versions are available
- Reporting in maintenance logs
- Knowing when to rebuild the image for security patches

### Curated Brewfile validation

The robot now validates `.devcontainer/brew/*.Brewfile` entries with Homebrew itself before
declaring a maintenance run healthy. This is intentionally validation-only:
- It does not rewrite Brewfiles
- It does not auto-upgrade formulas
- It does catch renamed formulas, missing taps, and other resolution errors that would otherwise
  surface later during DevPod/Codespaces post-create hydration

## CI Integration

The GitHub Actions workflow `.github/workflows/rcc-maintenance.yml` executes the `maintenance` task daily. When changes are detected (including pre-commit hook revision bumps), they are committed back to the repository.
