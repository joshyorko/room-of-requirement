# Deployment Overview

This document provides a high-level overview of the deployment flow for the Room of Requirement devcontainer image and placeholders for future deployment-related integrations.

## Environments
- **staging**: Manual promotion target for validation and smoke testing.
- **production**: Releases that are promoted from staging after sign-off.

## Release flow (recommended)
1. Build and push images via `.github/workflows/cicd.yaml` (already present).
2. Promote the specific `sha-<commit>` image to staging for validation.
3. Run any validation suites and smoke tests in staging.
4. If validation passes, promote the same image to production (manual approval recommended).

> Note: For now, promotion can be done by tagging images or updating the manifest in your deployment system to reference the `sha-<commit>` image. Future work can add a promotion workflow that automates this.

## Notifications (placeholder)
- Placeholder: integrate a notification step (Slack, Teams, or a generic webhook) to alert stakeholders on deploy success/failure.
- Make notifications configurable via repository secrets (for example `NOTIFICATIONS_WEBHOOK` and `NOTIFICATIONS_PROVIDER`).
- See `.github/workflows/notify-placeholder.yaml` for a disabled template you can enable when ready.

## Safety & Rollback
- Favor immutability (promote `sha-<commit>` tags) to ensure the exact image is promoted.
- On failure in staging or production, roll back to the previously known-good `sha-<commit>` image and open an incident/runbook entry.

## Runbooks & Troubleshooting (future)
- Add runbooks for common failures, such as:
  - Failed deploy due to image pull errors
  - High/critical vulnerabilities found post-deploy
  - Signature verification failures (once image signing is implemented)

---

If you'd like, I can:
- Add a staging promotion workflow with manual approvals, or
- Add the notification integration (disabled by default) and document the secrets required to enable it.
