#!/usr/bin/env python3
"""Enforce patched build Node and install the hash-verified CLI archive."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from ci_policy import require

CLI_VERSION = "0.89.0"


def capture(*args):
    return subprocess.check_output(args, text=True).strip()


def validate_node(version):
    match = re.fullmatch(r"v(24)\.([0-9]+)\.([0-9]+)", version)
    require(match is not None and tuple(map(int, match.groups())) >= (24, 22, 1),
            "build requires stable Node 24 >=24.22.1")


def verify_package(archive, metadata):
    require(metadata.get("name") == "@devcontainers/cli" and metadata.get("version") == CLI_VERSION,
            "unexpected CLI package identity")
    raw = archive.read_bytes()
    integrity = "sha512-" + base64.b64encode(hashlib.sha512(raw).digest()).decode()
    require(metadata.get("integrity") == integrity, "CLI package integrity mismatch")
    require(metadata.get("shasum") == hashlib.sha1(raw).hexdigest(), "CLI package shasum mismatch")
    return dict(name=metadata["name"], version=metadata["version"], integrity=integrity,
                sha256=hashlib.sha256(raw).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    version = capture("node", "--version")
    print(f"Build Node resolved to {version}", flush=True)
    validate_node(version)
    require(version == "v" + Path(".node-version").read_text().strip(), "Node pin/resolution mismatch")
    source = capture("git", "rev-parse", "HEAD")
    require(source == os.environ.get("EXPECTED_SOURCE", os.environ["GITHUB_SHA"]),
            "toolchain checkout/source mismatch")
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    # npm verifies registry integrity on fetch; retain and independently hash the
    # exact tarball installed below, rather than querying metadata after install.
    package = json.loads(capture("npm", "pack", f"@devcontainers/cli@{CLI_VERSION}",
                                 "--json", "--pack-destination", str(evidence)))[0]
    archive = evidence / package["filename"]
    require(archive.parent == evidence, "unexpected CLI archive path")
    receipt = verify_package(archive, package)
    subprocess.run(["npm", "install", "-g", str(archive)], check=True)
    require(capture("devcontainer", "--version") == CLI_VERSION, "installed CLI version mismatch")
    node_path = Path(shutil.which("node")).resolve()
    report = dict(source=source, repository=os.environ["GITHUB_REPOSITORY"], node=version,
                  node_path=str(node_path), node_sha256=hashlib.sha256(node_path.read_bytes()).hexdigest(),
                  npm=capture("npm", "--version"), cli=receipt,
                  registry="ghcr.io", image_repository="ghcr.io/" + os.environ["GITHUB_REPOSITORY"].lower(),
                  template_namespace=os.environ["GITHUB_REPOSITORY"].lower() + "/templates")
    (evidence / "toolchain.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        sys.exit(f"Build toolchain refused: {exc}")
