#!/usr/bin/env python3
"""Build a feature-aware candidate once; hand off its immutable registry digest."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tarfile

from ci_policy import context, require
from build_metadata import validate_labels
from image_identity import (digest, local_identity, registry_identity,
                            validate_local_image)


def capture(*args):
    return subprocess.check_output(args, text=True).strip()


def _stop_save(process):
    if process.stdout is not None and not process.stdout.closed:
        process.stdout.close()
    try:
        process.terminate()
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def saved_manifest(docker_id):
    docker_id = digest(docker_id)
    blob_name = "blobs/sha256/" + docker_id.removeprefix("sha256:")
    process = subprocess.Popen(["docker", "image", "save", docker_id],
                               stdout=subprocess.PIPE)
    raw_manifest = None
    try:
        with tarfile.open(fileobj=process.stdout, mode="r|", bufsize=1024 * 1024) as archive:
            for member in archive:
                if member.name != blob_name:
                    continue
                require(raw_manifest is None, "docker image save contains a duplicate manifest blob")
                require(member.isfile(), "docker image save manifest blob is not a regular file")
                require(0 <= member.size <= 4 * 1024 * 1024,
                        "docker image save manifest blob exceeds 4 MiB")
                source = archive.extractfile(member)
                require(source is not None, "docker image save manifest blob cannot be read")
                raw_manifest = source.read(member.size + 1)
                require(len(raw_manifest) == member.size,
                        "docker image save manifest blob size does not match its header")
        while process.stdout.read(1024 * 1024):
            pass
    except (tarfile.TarError, EOFError) as exc:
        _stop_save(process)
        raise ValueError("invalid docker image save archive") from exc
    except Exception:
        _stop_save(process)
        raise
    process.stdout.close()
    require(process.wait() == 0, "docker image save failed")
    require(raw_manifest is not None, "docker image save manifest blob missing")
    return raw_manifest


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
        # Refresh mutable apt/apk/Brew/feature installations when requested by the caller.
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
        inspected = json.loads(capture("docker", "image", "inspect", plan["test_image"],
                                       "--format", "{{json .}}"))
        validate_local_image(inspected, identity)
        plan["scan_image"] = "registry:" + plan["test_image"]
    else:
        inspected = json.loads(capture("docker", "image", "inspect", plan["candidate"],
                                       "--format", "{{json .}}"))
        descriptor = inspected.get("Descriptor")
        if descriptor is None:
            identity = local_identity(inspected)
        else:
            docker_id = digest(inspected.get("Id"))
            raw_manifest = saved_manifest(docker_id)
            identity = local_identity(inspected, raw_manifest)
            (evidence / "manifest.json").write_bytes(raw_manifest)
        docker_id = identity["docker_id"]
        plan["test_image"] = docker_id
        plan["scan_image"] = "docker:" + docker_id
    labels = inspected["Config"]["Labels"]
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
