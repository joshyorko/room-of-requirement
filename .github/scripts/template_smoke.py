#!/usr/bin/env python3
"""Apply the real OCI starter package using a disposable loopback-only registry."""

import argparse
import copy
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid

from ci_policy import VARIANTS, require


def capture(*args):
    return subprocess.check_output(args, text=True).strip()


def image_variant(image, repository):
    for variant, aliases in VARIANTS.items():
        if image in (f"ghcr.io/{repository.lower()}:{alias}" for alias in aliases):
            return variant
    raise ValueError("starter must target a supported image alias in this repository")


def metadata(root, repository):
    manifest = json.loads((root / "devcontainer-template.json").read_text())
    require(manifest.get("id") == "ror-starter", "unexpected starter ID")
    require(re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", manifest.get("version", "")),
            "invalid starter version")
    config = json.loads((root / ".devcontainer/devcontainer.json").read_text())
    return {"version": manifest["version"], "variant": image_variant(config["image"], repository)}


def isolate(config, image, prefix):
    result, volumes = copy.deepcopy(config), []
    result["image"] = image
    for index, mount in enumerate(result.get("mounts", [])):
        fields = dict(piece.split("=", 1) for piece in mount.split(",")) if isinstance(mount, str) else mount
        if fields.get("type") == "volume":
            name = f"{prefix}-{index}"
            fields["source"] = name
            volumes.append(name)
            result["mounts"][index] = (",".join(f"{k}={v}" for k, v in fields.items())
                                        if isinstance(mount, str) else fields)
    return result, volumes


def smoke(root, meta):
    require(meta["variant"] == os.environ["VARIANT"], "template/candidate variant mismatch")
    scripts = Path(__file__).resolve().parent
    evidence = Path(os.environ["RUNNER_TEMP"]) / "image-evidence"
    identity = "ror-ci-template-" + uuid.uuid4().hex
    registry = ""
    volumes = []
    try:
        # No public PR publication: this package registry is reachable only on loopback.
        registry = capture("docker", "run", "-d", "-p", "127.0.0.1::5000", "registry:3.0.0")
        port = capture("docker", "port", registry, "5000/tcp").split(":")[-1]
        require(port.isdecimal(), "invalid loopback registry port")
        endpoint = f"localhost:{port}"
        for attempt in range(30):
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/v2/", timeout=2) as response:
                    require(response.status == 200, "registry not ready")
                break
            except (urllib.error.URLError, TimeoutError):
                if attempt == 29:
                    raise
                time.sleep(1)
        subprocess.run(["devcontainer", "templates", "publish", str(root),
                        "--registry", endpoint, "--namespace", "ci/templates"], check=True)
        with tempfile.TemporaryDirectory(prefix=identity) as work:
            subprocess.run(["devcontainer", "templates", "apply", "--workspace-folder", work,
                            "--template-id", f'{endpoint}/ci/templates/ror-starter:{meta["version"]}'], check=True)
            config_path = Path(work) / ".devcontainer/devcontainer.json"
            applied = json.loads(config_path.read_text())
            require(image_variant(applied["image"], os.environ["GITHUB_REPOSITORY"]) == meta["variant"],
                    "applied template image changed unexpectedly")
            config, names = isolate(applied, os.environ["TEST_IMAGE"], identity)
            for name in names:
                subprocess.run(["docker", "volume", "create", name], check=True)
                volumes.append(name)
            config_path.write_text(json.dumps(config, indent=2) + "\n")
            # up builds template features and executes its real lifecycle commands.
            # This derived test image is never used to replace the verified candidate.
            result = capture("devcontainer", "up", "--workspace-folder", work,
                             "--id-label", "io.ror.ci-template=" + identity,
                             "--update-remote-user-uid-default", "never")
            (evidence / "template-up.json").write_text(result + "\n")
            container = json.loads(result)["containerId"]
            for script, user in (("docker-smoke.sh", None), ("podman-smoke.sh", "vscode")):
                if user and meta["variant"] != "wolfi":
                    continue
                args = ["docker", "exec", "-i"] + (["--user", user] if user else [])
                with (scripts / script).open() as source:
                    subprocess.run([*args, container, "bash", "--noprofile", "--norc", "-s"],
                                    stdin=source, check=True)
    finally:
        # Exact random ownership label also catches a failed up before it returns an ID.
        containers = capture("docker", "ps", "-aq", "--filter", "label=io.ror.ci-template=" + identity).split()
        for container in containers + ([registry] if registry else []):
            subprocess.run(["docker", "rm", "-f", "-v", container], check=True)
        for name in volumes:
            subprocess.run(["docker", "volume", "rm", name], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata", action="store_true")
    args = parser.parse_args()
    root = Path("templates/ror-starter").resolve()
    meta = metadata(root, os.environ["GITHUB_REPOSITORY"])
    if args.metadata:
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            output.write(f'variant={meta["variant"]}\n')
    else:
        smoke(root, meta)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as exc:
        sys.exit(f"Starter validation failed: {exc}")
