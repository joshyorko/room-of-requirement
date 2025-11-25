# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Room of Requirement is a cloud-native DevContainer setup providing a pre-configured development environment. It's not an application to build/test/run - it's a container image definition with automated maintenance tooling.

## Repository Structure

- `.devcontainer/` - Container definition (Dockerfile, devcontainer.json)
- `automation/maintenance-robot/` - RCC-powered maintenance bot that keeps dependencies updated
- `.github/workflows/` - CI/CD for automated maintenance

## Key Commands

### Run Maintenance Robot (full update)
```shell
rcc run -r automation/maintenance-robot/robot.yaml -t maintenance
```

### Run Specific Maintenance Tasks
```shell
# Update only GitHub Actions workflows
rcc run -r automation/maintenance-robot/robot.yaml -t update-workflows

# Update only download URLs in Dockerfile
rcc run -r automation/maintenance-robot/robot.yaml -t update-downloads
```

### Inspect RCC Environment
```shell
rcc holotree vars -r automation/maintenance-robot/robot.yaml
```

### Lint Dockerfile
```shell
hadolint .devcontainer/Dockerfile
```

## Architecture Notes

### Dockerfile Pattern
The Dockerfile uses multi-stage builds with version pinning via build ARGs at the top. All tool downloads include SHA256 checksum verification. When updating versions, both the version ARG and its corresponding SHA256 ARG must be updated together.

### Maintenance Robot
Python-based automation in `automation/maintenance-robot/src/maintenance_robot/` that:
- Reads allowlists from `automation/maintenance-robot/allowlists/` (JSON files)
- Queries GitHub API for latest allowed versions
- Updates version strings in Dockerfile and workflow files via regex patterns
- Outputs report to `automation/maintenance-robot/output/maintenance_report.json`

### Allowlist Strategy
- `allowlists/github_actions.json` - Actions constrained by max major version
- `allowlists/downloads.json` - Download URLs with regex patterns for version capture

## CI/CD

Daily maintenance runs via `.github/workflows/rcc-maintenance.yml` at 06:00 UTC. Creates PRs with changes automatically.
