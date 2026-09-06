#!/usr/bin/env python3
"""Short registry mutation boundary, run only under shared variant concurrency."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

from ci_policy import context, promotion, require


def capture(*args):
    return subprocess.check_output(args, text=True).strip()


def source_facts(plan):
    subprocess.run(["git", "fetch", "--no-tags", "origin",
                    "+refs/heads/main:refs/remotes/origin/main"], check=True)
    facts = {"main_sha": capture("git", "rev-parse", "refs/remotes/origin/main")}
    if plan["release_version"]:
        tag = "v" + plan["release_version"]
        subprocess.run(["git", "fetch", "--no-tags", "origin",
                        f"+refs/tags/{tag}:refs/ror-ci/release"], check=True)
        facts["tag_sha"] = capture("git", "rev-parse", "refs/ror-ci/release^{commit}")
        ancestry = subprocess.run(["git", "merge-base", "--is-ancestor", plan["source"],
                                   "refs/remotes/origin/main"], check=False)
        require(ancestry.returncode in (0, 1), "could not validate release ancestry")
        facts["main_ancestor"] = ancestry.returncode == 0
        release = json.loads(capture("gh", "release", "view", tag, "--repo", plan["repository"],
                                     "--json", "tagName,isDraft,isPrerelease"))
        require(release["isDraft"] is False and release["isPrerelease"] is False,
                "release is not published and stable")
        facts["release_tag"] = release["tagName"]
        latest = json.loads(capture("gh", "api", f'repos/{plan["repository"]}/releases/latest'))
        facts["latest_release"] = latest["tag_name"]
    return facts


def existing_image(reference):
    result = subprocess.run(["docker", "buildx", "imagetools", "inspect", reference,
                             "--format", "{{json .Image}}"],
                            capture_output=True, text=True, check=False)
    if result.returncode:
        # Absence is allowed; transport/auth/parse errors are not absence.
        message = result.stderr.lower()
        require("manifest unknown" in message or "not found" in message,
                "could not inspect existing alias: " + result.stderr)
        return None
    return json.loads(result.stdout)


def promote(plan, gates):
    plan = context(plan) | {"digest": plan["digest"], "gates": gates}
    # Validate policy before any registry access. Source facts are fresh inside the lock.
    aliases = promotion(plan | source_facts(plan))
    for alias in aliases:
        ref = plan["image"] + ":" + alias
        image = existing_image(ref)
        if image is None:
            continue
        labels = image["config"].get("Labels") or {}
        if "io.ror.run-id" in labels:
            previous = (int(labels["io.ror.run-id"]), int(labels["io.ror.run-attempt"]))
            current = (int(plan["run_id"]), int(plan["run_attempt"]))
            require(previous <= current, "newer run already promoted this alias")
        if plan["release_version"] and alias == aliases[0]:
            digest = capture("docker", "buildx", "imagetools", "inspect", ref,
                             "--format", "{{.Manifest.Digest}}")
            require(digest == plan["digest"], "exact release version already has a different digest")
    # Preflight may involve registry reads; recheck source immediately before mutation.
    require(aliases == promotion(plan | source_facts(plan)), "source changed during preflight")
    command = ["docker", "buildx", "imagetools", "create", "--prefer-index=false"]
    for alias in aliases:
        command.extend(["--tag", plan["image"] + ":" + alias])
    command.append(plan["image"] + "@" + plan["digest"])
    subprocess.run(command, check=True)
    for alias in aliases:
        actual = capture("docker", "buildx", "imagetools", "inspect",
                         plan["image"] + ":" + alias, "--format", "{{.Manifest.Digest}}")
        require(actual == plan["digest"], "promoted alias does not match verified digest")
    return aliases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("context", type=Path)
    args = parser.parse_args()
    plan = context(json.loads(args.context.read_text()))
    gates = {name: value["result"] for name, value in json.loads(os.environ["NEEDS"]).items()}
    aliases = promote(plan, gates)
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
        summary.write(f'Verified image: `{plan["image"]}@{plan["digest"]}`\n\n')
        summary.write("Promoted aliases: " + ", ".join(aliases) + "\n")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as exc:
        sys.exit(f"Promotion refused: {exc}")
