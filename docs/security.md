# Security: Container Scanning with Trivy

✅ This repository now runs a Trivy container scan as part of CI to detect container image vulnerabilities.

## What runs
- A dedicated `container-scan` job runs after `build-and-push` and scans the built image tag `sha-${{ github.sha }}`.
- The scan uses `aquasecurity/trivy-action` and will fail the workflow if any **HIGH** or **CRITICAL** vulnerabilities are found.

## Artifacts
- `trivy.sarif` (uploaded as `trivy-sarif`) — SARIF formatted results for easy import/analysis.
- `trivy-full.json` (uploaded as `trivy-json`) — full Trivy JSON output for debugging.

## Config & Secrets
- The workflow uses the repository `GITHUB_TOKEN` to authenticate to GHCR (no extra secrets required for GHCR access).
- If you scan images in a private registry that requires separate credentials, add the appropriate secrets (e.g., `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`) and update the workflow to use them.

## Run locally
- Quick check (Docker required):

```bash
# scans ghcr.io/joshyorko/ror:latest by default
scripts/run-trivy-local.sh [image]
```

## Failure policy and next steps
- If the CI scan fails due to HIGH/CRITICAL vulnerabilities, the workflow will be marked failed and artifacts uploaded for triage.
- Triage steps: examine `trivy-full.json`, prioritize fixes or upgrades of affected packages, and consider backport or rollback of vulnerable images.

---

If you'd like, I can also:
- Add automatic Slack/Teams notifications when the scan fails, and
- Add a scheduled workflow that regularly scans the `latest` image and notifies stakeholders if something regresses.
