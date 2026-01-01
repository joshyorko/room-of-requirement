# Runbook: High/Critical Vulnerability Found in Production Image

Symptoms
- CI or scheduled scan reports HIGH/CRITICAL vulnerabilities for the `latest` image or a promoted image.

Quick checks
1. Retrieve the SARIF or JSON artifact from the CI run for details.
2. Identify whether the vulnerability affects a critical package or can be mitigated by configuration.

Immediate mitigation
- Depending on severity, consider reverting to the previously known-good image (rollback to `sha-<commit>`).
- If a fix is available in the base image or one dependency, plan a fix and schedule an emergency release.

Follow-up
- Add a scheduled scan for `latest` if not already present.
- If the issue is widely impactful, follow incident process and notify stakeholders.
