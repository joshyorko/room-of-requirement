# Runbook: Failed Deploy (image pull / general failure)

Symptoms
- Deploy step fails with an image pull error or the deployment status is CrashLoopBackOff.

Quick checks
1. Confirm the image exists in GHCR and the tag matches (use the `sha-<commit>` tag published in the CI summary).
2. Check the cluster can access GHCR — confirm credentials if private.
3. Examine recent pod events and logs: `kubectl describe pod <pod>` and `kubectl logs <pod>`.

Immediate mitigation
- Roll back to last known good image: update deployment to previous `sha-<commit>` and `kubectl rollout restart`.

Follow-up
- Investigate root cause: image missing, image corruption, registry permissions, or misconfiguration in manifests.
- Add monitoring for image pull failures and alert via your notification system.
