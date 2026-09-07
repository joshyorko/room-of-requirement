#!/usr/bin/env python3
"""Bind the successful isolated generator to this candidate's signed claims."""

import os
import subprocess
import sys

from ci_policy import require
from image_identity import digest


def main():
    require(os.environ["GENERATOR_RESULT"] == "success", "provenance generator did not succeed")
    subject = digest(os.environ["DIGEST"])
    # Payloads are unused here; keep large attestations out of the Actions log.
    subprocess.run([
        "cosign", "verify-attestation", "--check-claims", "--type", "slsaprovenance",
        # SLSA v2.1.0 writes Cosign 2.2.3 legacy attestations. Existing v3 SPDX/context
        # bundles suppress Cosign 3's automatic legacy fallback; select it explicitly.
        "--new-bundle-format=false",
        "--certificate-identity",
        "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/v2.1.0",
        "--certificate-oidc-issuer", "https://token.actions.githubusercontent.com",
        os.environ["IMAGE"] + "@" + subject,
    ], check=True, stdout=subprocess.DEVNULL)
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"subject_digest={subject}\n")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        sys.exit(f"Provenance subject gate failed: {exc}")
