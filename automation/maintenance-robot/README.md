# Maintenance Robot

Automated upkeep for the Room of Requirement repository leveraging `rcc` and Robocorp tasks.

## Overview

This robot keeps the DevContainer and GitHub Actions workflows fresh by:

- Checking GitHub repositories for newer action releases allowed by curated allowlists.
- Updating pinned download URLs (for example `kind` and `rcc`) in the DevContainer Dockerfile based on latest permitted versions.
- Producing a machine-readable maintenance report that summarises all applied updates.

The implementation mirrors the automation patterns used in the Sema4.AI gallery publisher so it can run both locally via `rcc` and inside GitHub Actions.

## Repository Layout

```
automation/maintenance-robot/
├── allowlists/
│   ├── downloads.json          # regex targets + GitHub repos used for version discovery
│   └── github_actions.json     # allowlisted actions + constraints
├── conda.yaml                  # execution environment (Python 3.11 + uv + robocorp)
├── robot.yaml                  # robot definition consumed by rcc
├── src/maintenance_robot/
│   ├── __init__.py
│   ├── allowlist_loader.py
│   ├── downloads.py
│   ├── github_actions.py
│   ├── github_api.py
│   ├── reporter.py
│   └── tasks.py
└── README.md
```

Generated artefacts (for example `output/maintenance_report.json`) are ignored via `.gitignore`.

## Running Locally

1. Ensure `rcc` is available (the DevContainer already installs it).
2. From the repository root run:

```shell
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance
```

Optional task targets:
- `update-workflows` – only update GitHub Actions workflow `uses:` references.
- `update-downloads` – only update download URLs declared in `downloads.json`.

To inspect the resolved environment without running the robot:

```shell
rcc holotree vars -r automation/maintenance-robot/robot.yaml
```

A summary of changes is written to `automation/maintenance-robot/output/maintenance_report.json`.

## Allowlist Strategy

- Action updates are constrained by maximum major version and release source (`release` or `tag`).
- Download updates rely on regex patterns that capture semantic versions within target files.
- Additional targets can be added by editing the respective allowlist JSON files.

## CI Integration

The GitHub Actions workflow `.github/workflows/rcc-maintenance.yml` executes the `maintenance` task daily. When changes are detected, they are committed back to the repository using the built-in `GITHUB_TOKEN`.
