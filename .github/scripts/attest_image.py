#!/usr/bin/env python3
"""Validate SPDX evidence, then sign and verify the candidate digest and its SBOM."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from ci_policy import require


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    evidence = Path(os.environ["RUNNER_TEMP"]) / "image-evidence"
    predicate = evidence / "sbom.spdx.json"
    sbom = json.loads(predicate.read_text())
    require(sbom.get("spdxVersion") in ("SPDX-2.2", "SPDX-2.3")
            and sbom.get("SPDXID") == "SPDXRef-DOCUMENT"
            and isinstance(sbom.get("documentNamespace"), str)
            and sbom["documentNamespace"]
            and isinstance(sbom.get("packages"), list), "invalid SPDX SBOM")
    if args.validate_only:
        return
    plan = json.loads((evidence / "context.json").read_text())
    require(plan["image"] == os.environ["IMAGE"] and plan["digest"] == os.environ["DIGEST"],
            "SBOM evidence candidate does not match the job's digest")
    require(re.fullmatch(r"sha256:[a-f0-9]{64}", plan["digest"]), "invalid digest")
    require(re.fullmatch(r"[a-f0-9]{40}", plan["source"]), "invalid build source")
    ref = plan["image"] + "@" + plan["digest"]
    subprocess.run(["cosign", "sign", "--yes", ref], check=True)
    subprocess.run(["cosign", "attest", "--yes", "--predicate", str(predicate),
                    "--type", "spdxjson", ref], check=True)
    # The isolated SLSA generator records the triggering workflow revision.
    # A release may intentionally check out an older tagged source. Bind that
    # explicit source and the builder inputs to the same digest as well.
    build_context = evidence / "build-context.json"
    build_context.write_text(json.dumps(plan, indent=2) + "\n")
    context_type = "https://github.com/" + os.environ["GITHUB_REPOSITORY"] + "/attestations/build-context/v1"
    subprocess.run(["cosign", "attest", "--yes", "--predicate", str(build_context),
                    "--type", context_type, ref], check=True)
    identity = (r"^https://github.com/" + re.escape(os.environ["GITHUB_REPOSITORY"])
                + r"/\.github/workflows/(build-image|build-devcontainers|release)\.yml@"
                + re.escape(os.environ["GITHUB_REF"]) + "$")
    identity_args = ["--certificate-identity-regexp", identity,
                     "--certificate-oidc-issuer", "https://token.actions.githubusercontent.com"]
    subprocess.run(["cosign", "verify", *identity_args, ref], check=True)
    subprocess.run(["cosign", "verify-attestation", *identity_args,
                    "--type", "spdxjson", ref], check=True)
    subprocess.run(["cosign", "verify-attestation", *identity_args,
                    "--type", context_type, ref], check=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as exc:
        sys.exit(f"Attestation gate failed: {exc}")
