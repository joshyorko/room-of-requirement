#!/usr/bin/env python3
"""The pipeline supports one linux/amd64 image manifest, never an OCI index."""

import hashlib
import json
import os
from pathlib import Path
import re
import sys

from ci_policy import require

IMAGE_TYPES = ("application/vnd.oci.image.manifest.v1+json",
               "application/vnd.docker.distribution.manifest.v2+json")


def digest(value):
    require(isinstance(value, str) and re.fullmatch(r"sha256:[a-f0-9]{64}", value),
            "invalid immutable image identity")
    return value


def registry_identity(raw_manifest, expected_digest):
    expected_digest = digest(expected_digest)
    require("sha256:" + hashlib.sha256(raw_manifest).hexdigest() == expected_digest,
            "registry manifest bytes do not match candidate digest")
    manifest = json.loads(raw_manifest)
    require(manifest.get("mediaType") in IMAGE_TYPES and "manifests" not in manifest,
            "candidate must be a single image manifest, not an index")
    require(manifest.get("schemaVersion") == 2, "unsupported image manifest schema")
    return {"mode": "registry", "manifest_digest": expected_digest,
            "config_digest": digest(manifest["config"]["digest"])}


def scan_identity(source, expected):
    require(isinstance(source, dict) and source.get("type") == "image", "image scan source missing")
    target = source.get("target")
    require(isinstance(target, dict), "image scan target missing")
    require(expected["mode"] in ("registry", "local"), "unsupported expected image identity")
    require(digest(target.get("imageID")) == digest(expected.get("config_digest")),
            "scan config imageID does not match tested image")
    if expected["mode"] == "registry":
        require(target.get("mediaType") in IMAGE_TYPES, "scan is not a single image manifest")
        require(digest(target.get("manifestDigest")) == digest(expected.get("manifest_digest")),
                "scan manifest does not match published candidate")
    else:
        require(not expected.get("manifest_digest"), "local identity cannot claim a registry manifest")
    return expected


def verified_subject(plan, identity, scan):
    require(scan["subject"] == identity, "scan evidence belongs to another image")
    require(scan["enforce"] is plan["enforce"], "scan enforcement policy mismatch")
    require(not plan["enforce"] or scan["critical_fixed"] == 0, "scan policy failed")
    if plan["publish"]:
        require(identity["mode"] == "registry", "published image lacks manifest identity")
        require(plan["digest"] == digest(identity["manifest_digest"]), "verification subject mismatch")
        require(plan["test_image"] == plan["image"] + "@" + plan["digest"], "runtime subject mismatch")
        return plan["digest"]
    require(identity["mode"] == "local" and plan["test_image"] == identity["config_digest"],
            "local runtime subject mismatch")
    return ""


if __name__ == "__main__":
    try:
        evidence = Path(os.environ["RUNNER_TEMP"]) / "image-evidence"
        values = [json.loads((evidence / name).read_text()) for name in
                  ("context.json", "identity.json", "scan-summary.json")]
        subject = verified_subject(*values)
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            output.write(f"subject_digest={subject}\n")
    except (ValueError, KeyError, TypeError, OSError) as exc:
        sys.exit(f"Verification subject gate failed: {exc}")
