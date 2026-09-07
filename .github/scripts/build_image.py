#!/usr/bin/env python3
"""Build a feature-aware candidate once; hand off its immutable registry digest."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys

from ci_policy import context, require
from build_metadata import validate_labels
from image_identity import digest, registry_identity


def capture(*args):
    return subprocess.check_output(args, text=True).strip()


def main():
    plan = context(json.loads(os.environ["REQUEST"]))
    require(capture("git", "rev-parse", "HEAD") == plan["source"], "checkout/source mismatch")
    evidence = Path(os.environ["RUNNER_TEMP"]) / "image-evidence"
    evidence.mkdir(parents=True, exist_ok=True)
    cache = f'{plan["image"]}/buildcache:{plan["cache_scope"]}'
    command = ["devcontainer", "build", "--workspace-folder", ".", "--config",
               f'src/{plan["variant"]}/.devcontainer/devcontainer.json',
               "--image-name", plan["candidate"], "--platform", "linux/amd64",
               "--frozen-lockfile", "--cache-from", f"type=registry,ref={cache}",
               "--docker-path", str(Path(__file__).resolve().with_name("build_metadata.py"))]
    if plan["refresh"]:
        # CLI 0.89.0 forwards --no-cache AND --pull for Dockerfile builds,
        # refreshing mutable apt/apk/Brew/feature installations on the monthly run.
        command.append("--no-cache")
    if plan["publish"]:
        command.append("--push")
        # PRs/branch candidates can read trusted cache but cannot replace it.
        if plan["ref"] == "refs/heads/main":
            command.extend(["--cache-to", f"type=registry,ref={cache},mode=max"])
    with (evidence / "build.json").open("w") as output:
        # Default Buildx attestations create an OCI index even for one platform.
        # We attach our required attestations later and deliberately publish one manifest.
        subprocess.run(command, check=True, stdout=output,
                       env=dict(os.environ, BUILDX_NO_DEFAULT_ATTESTATIONS="1",
                                ROR_BUILD_CONTEXT=json.dumps(plan)))
    plan["digest"] = ""
    plan["test_image"] = plan["candidate"]
    if plan["publish"]:
        plan["digest"] = capture("docker", "buildx", "imagetools", "inspect",
                                 plan["candidate"], "--format", "{{.Manifest.Digest}}")
        require(re.fullmatch(r"sha256:[a-f0-9]{64}", plan["digest"]), "invalid registry digest")
        raw_manifest = subprocess.check_output(["docker", "buildx", "imagetools", "inspect",
                                                plan["candidate"], "--raw"])
        identity = registry_identity(raw_manifest, plan["digest"])
        (evidence / "manifest.json").write_bytes(raw_manifest)
        plan["test_image"] = plan["image"] + "@" + plan["digest"]
        subprocess.run(["docker", "pull", plan["test_image"]], check=True)
        local_id = capture("docker", "image", "inspect", plan["test_image"], "--format", "{{.Id}}")
        require(local_id == identity["config_digest"], "pulled image differs from candidate config")
        plan["scan_image"] = "registry:" + plan["test_image"]
    else:
        local_id = digest(capture("docker", "image", "inspect", plan["candidate"], "--format", "{{.Id}}"))
        identity = {"mode": "local", "config_digest": local_id}
        plan["test_image"] = local_id
        plan["scan_image"] = "docker:" + local_id
    labels = json.loads(capture("docker", "image", "inspect", plan["test_image"],
                                 "--format", "{{json .Config.Labels}}"))
    validate_labels(labels, plan)
    (evidence / "metadata.json").write_text(json.dumps(labels, indent=2) + "\n")
    (evidence / "identity.json").write_text(json.dumps(identity, indent=2) + "\n")
    (evidence / "context.json").write_text(json.dumps(plan, indent=2) + "\n")
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        for key in ("image", "candidate", "test_image", "scan_image", "digest", "source", "publish", "enforce"):
            value = plan[key]
            output.write(f"{key}={str(value).lower() if isinstance(value, bool) else value}\n")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        sys.exit(f"Build failed: {exc}")
