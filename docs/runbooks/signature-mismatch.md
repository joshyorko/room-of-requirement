# Runbook: Signature Verification Failure

Symptoms
- Downstream verification job or deployment rejects the image due to signature mismatch or missing signature.

Quick checks
1. Confirm the signature exists in the registry or the signature artifact in the CI run.
2. Verify the public key used for verification is the correct one (rotations can cause mismatches).

Immediate mitigation
- Do not promote the image to production. Roll back to the last known-good signed image.
- If verification keys were rotated unintentionally, re-issue signatures with the correct keys after rotation policy review.

Follow-up
- Document key rotation policy and who has access to sign images.
- Ensure verification jobs are part of the pre-deploy checks.
