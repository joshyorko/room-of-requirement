#!/usr/bin/env python3
"""Metadata on the final build via Dev Containers CLI's supported --docker-path.

CLI 0.89.0 drops its --label option on Dockerfile builds. This narrow adapter
labels only the candidate-tagged Docker build; all other Docker calls pass through.
"""

import json
import os
import re
import sys

from ci_policy import context, require

MARKER = "io.ror.publication"


def labels_for(plan):
    return {
        MARKER: "verified-v1",
        "org.opencontainers.image.source": "https://github.com/" + plan["repository"],
        "org.opencontainers.image.revision": plan["source"],
        "io.ror.run-id": str(plan["run_id"]),
        "io.ror.run-attempt": str(plan["run_attempt"]),
    }


def validate_labels(labels, plan):
    require(isinstance(labels, dict), "candidate build metadata missing")
    for key, value in labels_for(plan).items():
        require(labels.get(key) == value, f"candidate metadata mismatch: {key}")


def previous_order(labels, repository):
    require(isinstance(labels, dict), "alias labels malformed")
    # Unmarked, pre-pipeline aliases can be adopted. New candidates cannot become
    # aliases without passing validate_labels both after pull and before promotion.
    if not any(key.startswith("io.ror.") for key in labels):
        return None
    require(labels.get(MARKER) == "verified-v1", "alias publication marker missing or unsupported")
    require(labels.get("org.opencontainers.image.source") == "https://github.com/" + repository,
            "alias repository metadata mismatch")
    require(re.fullmatch(r"[a-f0-9]{40}", labels.get("org.opencontainers.image.revision", "")),
            "alias source metadata missing")
    order = []
    for key in ("io.ror.run-id", "io.ror.run-attempt"):
        value = labels.get(key, "")
        require(isinstance(value, str) and re.fullmatch(r"[1-9][0-9]*", value),
                f"alias run metadata missing or invalid: {key}")
        order.append(int(value))
    return tuple(order)


def docker_args(args, plan):
    is_build = args[:2] == ["buildx", "build"] or args[:1] == ["build"]
    tags = [args[i + 1] for i, value in enumerate(args[:-1]) if value in ("-t", "--tag")]
    if is_build and plan["candidate"] in tags:
        options = []
        for key, value in labels_for(plan).items():
            options.extend(["--label", f"{key}={value}"])
        # Pinned CLI emits the context last. Put our labels after its options so
        # feature/config labels cannot override the publication metadata.
        return [*args[:-1], *options, args[-1]]
    return args


if __name__ == "__main__":
    try:
        request = context(json.loads(os.environ["ROR_BUILD_CONTEXT"]))
        os.execvp("docker", ["docker", *docker_args(sys.argv[1:], request)])
    except (ValueError, KeyError, TypeError, OSError) as exc:
        sys.exit(f"Build metadata adapter failed: {exc}")
