#!/usr/bin/env python3
"""Apply the real OCI starter package using a disposable loopback-only registry."""

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import struct
import subprocess
import sys
import tempfile
import time
import tomllib
import urllib.error
import urllib.request
import uuid

from ci_policy import VARIANTS, require
from build_toolchain import validate_node


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


def prepare_workspace(work, candidate_uid):
    """Grant both UIDs access only to this runner-owned disposable payload.

    Linux POSIX ACL xattrs avoid a host setfacl dependency. Default directory
    ACLs keep runner cleanup access to files/directories created by the image UID.
    """
    require(not work.is_symlink() and work.stat().st_uid == os.getuid(),
            "template workspace must be owned by the runner")
    require(0 <= candidate_uid < 0xffffffff, "invalid candidate UID")
    uids = sorted({os.getuid(), candidate_uid})

    def acl(permissions):
        # Linux posix_acl_xattr: version 2; owner, named users, group, mask, other.
        entries = [(1, permissions, 0xffffffff)] + [(2, permissions, uid) for uid in uids]
        entries += [(4, 0, 0xffffffff), (16, permissions, 0xffffffff), (32, 0, 0xffffffff)]
        return struct.pack("<I", 2) + b"".join(struct.pack("<HHI", *entry) for entry in entries)

    for directory, _, files in os.walk(work, followlinks=False):
        os.setxattr(directory, "system.posix_acl_access", acl(7), follow_symlinks=False)
        os.setxattr(directory, "system.posix_acl_default", acl(7), follow_symlinks=False)
        for name in files:
            path = Path(directory) / name
            mode = path.lstat().st_mode
            if stat.S_ISREG(mode):
                os.setxattr(path, "system.posix_acl_access", acl(7 if mode & 0o111 else 6),
                            follow_symlinks=False)


def payload_hashes(root):
    return {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(root.rglob("*")) if path.is_file()}


def package_evidence(endpoint, version):
    """Verify the OCI bytes actually used by the loopback apply operation."""
    base = f"http://{endpoint}/v2/ci/templates/ror-starter"
    request = urllib.request.Request(base + "/manifests/" + version,
                                     headers={"Accept": "application/vnd.oci.image.manifest.v1+json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        raw = response.read()
        digest = "sha256:" + hashlib.sha256(raw).hexdigest()
        require(response.headers.get("Docker-Content-Digest") == digest, "template manifest digest mismatch")
    manifest = json.loads(raw)
    layers = manifest["layers"]
    require(layers, "template package layers missing")
    for descriptor in [manifest["config"], *layers]:
        require(re.fullmatch(r"sha256:[a-f0-9]{64}", descriptor["digest"]), "invalid template layer digest")
        with urllib.request.urlopen(base + "/blobs/" + descriptor["digest"], timeout=30) as response:
            content = response.read()
        require("sha256:" + hashlib.sha256(content).hexdigest() == descriptor["digest"],
                "template package hash mismatch")
    return dict(manifest_digest=digest, config=manifest["config"], layers=layers)


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
        package = package_evidence(endpoint, meta["version"])
        with tempfile.TemporaryDirectory(prefix=identity) as work:
            subprocess.run(["devcontainer", "templates", "apply", "--workspace-folder", work,
                            "--template-id", f'{endpoint}/ci/templates/ror-starter@{package["manifest_digest"]}'], check=True)
            config_path = Path(work) / ".devcontainer/devcontainer.json"
            applied = json.loads(config_path.read_text())
            require(image_variant(applied["image"], os.environ["GITHUB_REPOSITORY"]) == meta["variant"],
                    "applied template image changed unexpectedly")
            receipt = dict(source=capture("git", "rev-parse", "HEAD"),
                           repository=os.environ["GITHUB_REPOSITORY"], package=package,
                           source_files=payload_hashes(root), applied_files=payload_hashes(Path(work)),
                           declared_image=applied["image"], tested_image=os.environ["TEST_IMAGE"],
                           declared_tools=tomllib.loads((Path(work) / ".mise.toml").read_text())["tools"],
                           node_scope="Template file hashes and runtime declarations; embedded image Node is inventoried separately")
            (evidence / "template-package.json").write_text(json.dumps(receipt, indent=2) + "\n")
            config, names = isolate(applied, os.environ["TEST_IMAGE"], identity)
            for name in names:
                subprocess.run(["docker", "volume", "create", name], check=True)
                volumes.append(name)
            config_path.write_text(json.dumps(config, indent=2) + "\n")
            candidate_uid = int(capture("docker", "run", "--rm", "--user", "root", "--entrypoint", "id",
                                        os.environ["TEST_IMAGE"], "-u", str(config.get("remoteUser", "vscode"))))
            prepare_workspace(Path(work), candidate_uid)
            # up builds template features and executes its real lifecycle commands.
            # This derived test image is never used to replace the verified candidate.
            result = capture("devcontainer", "up", "--workspace-folder", work,
                             "--id-label", "io.ror.ci-template=" + identity,
                             "--update-remote-user-uid-default", "never")
            (evidence / "template-up.json").write_text(result + "\n")
            container = json.loads(result)["containerId"]
            node = capture("devcontainer", "exec", "--workspace-folder", work,
                           "mise", "exec", "--", "node", "--version")
            validate_node(node)
            (evidence / "template-node.txt").write_text(node + "\n")
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
