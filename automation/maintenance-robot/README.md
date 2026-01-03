# Maintenance Robot

Automated upkeep for the Room of Requirement repository leveraging `rcc` and Robocorp tasks.

## Overview

This robot keeps the repository fresh by automating version updates for:

1. **GitHub Actions workflows** - Updates `uses:` references based on allowlisted actions
2. **PyPI packages** - Updates pinned versions in `conda.yaml` for the maintenance robot itself
3. **Homebrew tracking** - Logs formula versions (informational only)

### What This Robot Does NOT Update

**Homebrew packages are NOT auto-updated.** With our Homebrew-first architecture:
- Core tools (mise, starship, zoxide, nushell) are baked into the image via `core.Brewfile`
- On-demand tools are installed via curated Brewfiles in `.devcontainer/brew/`
- Homebrew handles versioning naturally via `brew update && brew upgrade`
- The `homebrew.json` allowlist is informational only - it logs versions but doesn't modify files

## Repository Layout

```
automation/maintenance-robot/
├── allowlists/
│   ├── downloads.json          # PyPI packages (with regex patterns)
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
2. From the repository root run:

```shell
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance
```

### Available Tasks

| Task | Command | Description |
|------|---------|-------------|
| **maintenance** | `-t maintenance` | Full maintenance run (recommended) |
| **update-workflows** | `-t update-workflows` | Update GitHub Actions only |
| **update-downloads** | `-t update-downloads` | Update PyPI packages only |
| **update-lockfile** | `-t update-lockfile` | Regenerate devcontainer-lock.json only |
| **update-homebrew** | `-t update-homebrew` | Log Homebrew versions (informational only) |
| **test-devcontainer** | `-t test-devcontainer` | Test devcontainer build |

To inspect the resolved environment without running the robot:

```shell
rcc holotree vars -r automation/maintenance-robot/robot.yaml
```

A summary of changes is written to `automation/maintenance-robot/output/maintenance_report.json`.

## Allowlist Strategy

### downloads.json

Targets files for version updates:
- **PyPI packages**: Fetch latest version for Python dependencies
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

**Informational only** - tracks versions of core tools baked into the image.
No file updates are performed. This is useful for:
- Monitoring what versions are available
- Reporting in maintenance logs
- Knowing when to rebuild the image for security patches

## CI Integration

The GitHub Actions workflow `.github/workflows/rcc-maintenance.yml` executes the `maintenance` task daily. When changes are detected, they are committed back to the repository.
