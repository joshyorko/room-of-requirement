#!/usr/bin/env python3
"""Publish the starter only after candidate/template checks at current main."""

import os
import subprocess
import sys

from ci_policy import require
from promote_image import capture, source_facts
from template_smoke import metadata
from pathlib import Path


def main():
    require(os.environ["GITHUB_REF"] == "refs/heads/main", "only main can publish templates")
    require(os.environ["GITHUB_EVENT_NAME"] in ("push", "workflow_dispatch"), "invalid publisher event")
    require(os.environ["VALIDATION_RESULT"] == "success", "template pipeline did not succeed")
    source = os.environ["GITHUB_SHA"]
    require(capture("git", "rev-parse", "HEAD") == source, "checkout/source mismatch")
    facts = source_facts({"release_version": ""})
    require(facts["main_sha"] == source, "template source no longer current main")
    metadata(Path("templates/ror-starter"), os.environ["GITHUB_REPOSITORY"])
    subprocess.run(["devcontainer", "templates", "publish", "templates/ror-starter",
                    "--registry", "ghcr.io", "--namespace",
                    os.environ["GITHUB_REPOSITORY"].lower() + "/templates"], check=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        sys.exit(f"Template publication refused: {exc}")
