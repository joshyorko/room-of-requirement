#!/usr/bin/env python3
"""Pure publication policy, shared by the builder and the final registry writer."""

import json
import re
import sys

VARIANTS = {
    "ubuntu-noble": ["ubuntu-noble", "ubuntu-noble-dind", "latest", "codespaces"],
    "debian-trixie": ["debian-trixie"],
    "wolfi": ["wolfi", "secure"],
}


def boolean(value, default=True):
    # Do not use Actions loose comparisons or Python truthiness for absent inputs.
    if value is None or value == "":
        return default
    if value is True or value == "true":
        return True
    if value is False or value == "false":
        return False
    raise ValueError("expected a Boolean or an absent input")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def context(data):
    result = dict(data)
    require(data["variant"] in VARIANTS, "unsupported variant")
    require(re.fullmatch(r"[a-f0-9]{40}", data["source"]), "invalid source SHA")
    require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", data["repository"]),
            "invalid repository")
    for name in ("run_id", "run_attempt"):
        require(re.fullmatch(r"[1-9][0-9]*", str(data[name])), f"invalid {name}")
    result["enforce"] = boolean(data.get("enforce"))
    result["publish"] = (boolean(data.get("publish"), False)
                         and data["event"] in ("push", "schedule", "workflow_dispatch"))
    result["refresh"] = boolean(data.get("refresh"), False) or data["event"] == "schedule"
    result["repository"] = data["repository"].lower()
    result["image"] = "ghcr.io/" + result["repository"]
    result["candidate"] = (f'{result["image"]}:candidate-{data["variant"]}-'
                           f'{data["run_id"]}-{data["run_attempt"]}')
    result["cache_scope"] = f'ror-{data["variant"]}-amd64'
    result["release_version"] = data.get("release_version", "")
    if result["release_version"]:
        require(re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)",
                             result["release_version"]), "invalid stable release version")
    return result


def promotion(data):
    plan = context(data)
    require(plan["publish"] and plan["enforce"], "publication requires enforced policy")
    require(re.fullmatch(r"sha256:[a-f0-9]{64}", data.get("digest", "")), "invalid digest")
    for name in ("verify", "attest", "provenance"):
        require(data.get("gates", {}).get(name) == "success", f"gate not successful: {name}")
    version = plan["release_version"]
    if version:
        tag = "v" + version
        require(plan["ref"] in ("refs/heads/main", "refs/tags/" + tag),
                "release promotion requires main or its exact release ref")
        require(data.get("tag_sha") == plan["source"], "release tag/source mismatch")
        require(data.get("main_ancestor") is True, "release source is not on main")
        require(data.get("release_tag") == tag, "published stable release missing")
        require(data.get("latest_release") == tag, "release superseded; refusing rolling tags")
        major, minor, _ = version.split(".")
        suffix = "" if plan["variant"] == "ubuntu-noble" else "-" + plan["variant"]
        return [tag + suffix, f"v{major}.{minor}{suffix}", f"v{major}{suffix}"]
    require(plan["ref"] == "refs/heads/main", "only main can promote production aliases")
    require(plan["source"] == data.get("main_sha"), "source no longer current main")
    tags = list(VARIANTS[plan["variant"]])
    if plan["event"] == "schedule" and plan["variant"] == "ubuntu-noble":
        tags.append("stable")
    return tags


if __name__ == "__main__":
    try:
        operation = {"context": context, "promotion": promotion}[sys.argv[1]]
        print(json.dumps(operation(json.load(sys.stdin))))
    except (ValueError, KeyError, TypeError, IndexError) as exc:
        sys.exit(f"CI policy rejected request: {exc}")
