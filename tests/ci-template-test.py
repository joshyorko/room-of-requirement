#!/usr/bin/env python3
"""Starter application retains lifecycle/features and only isolates CI storage."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / ".github/scripts"
sys.path.insert(0, str(SCRIPTS))


class TemplateTests(unittest.TestCase):
    def module(self):
        self.assertTrue((SCRIPTS / "template_smoke.py").exists())
        spec = importlib.util.spec_from_file_location("template", SCRIPTS / "template_smoke.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_supported_target_selects_matching_variant_and_rejects_stale_repository(self):
        module = self.module()
        for alias, variant in (("latest", "ubuntu-noble"), ("secure", "wolfi"),
                               ("debian-trixie", "debian-trixie")):
            self.assertEqual(module.image_variant("ghcr.io/owner/repo:" + alias, "owner/repo"), variant)
        for image in ("ghcr.io/owner/ror:latest", "ubuntu:latest", "ghcr.io/owner/repo:topic"):
            with self.assertRaises(ValueError):
                module.image_variant(image, "owner/repo")

    def test_applied_payload_preserves_features_and_lifecycle_but_isolates_volumes(self):
        module = self.module()
        config = dict(image="ghcr.io/owner/repo:wolfi", features={"feature:1": {}},
                      postCreateCommand="hydrate-required", remoteUser="vscode", mounts=[
                          "source=live-home,target=/home/vscode,type=volume",
                          {"source": "live-docker", "target": "/var/lib/docker", "type": "volume"},
                          "source=${localWorkspaceFolder},target=/workspace,type=bind"])
        original = copy.deepcopy(config)
        changed, volumes = module.isolate(config, "local:candidate", "ror-ci-template-123")
        self.assertEqual(config, original)
        self.assertEqual(changed["image"], "local:candidate")
        self.assertEqual(changed["features"], {"feature:1": {}})
        self.assertEqual(changed["postCreateCommand"], "hydrate-required")
        self.assertEqual(changed["mounts"][2], original["mounts"][2])
        self.assertEqual(volumes, ["ror-ci-template-123-0", "ror-ci-template-123-1"])
        self.assertNotIn("live-home", json.dumps(changed))
        self.assertNotIn("live-docker", json.dumps(changed))

    def test_manifest_validation_does_not_accept_missing_or_mismatched_payload(self):
        module = self.module()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / ".devcontainer").mkdir()
            (root / "devcontainer-template.json").write_text(json.dumps(dict(id="ror-starter", version="1.0.0")))
            (root / ".devcontainer/devcontainer.json").write_text(json.dumps(dict(image="ghcr.io/owner/repo:wolfi")))
            self.assertEqual(module.metadata(root, "owner/repo")["variant"], "wolfi")
            (root / "devcontainer-template.json").write_text('{"id":"wrong"}')
            with self.assertRaises(ValueError):
                module.metadata(root, "owner/repo")

    def test_template_publisher_refuses_failed_validation_branch_and_stale_source(self):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            template = work / "templates/ror-starter"
            (template / ".devcontainer").mkdir(parents=True)
            (template / "devcontainer-template.json").write_text(
                '{"id":"ror-starter","version":"1.0.0"}')
            (template / ".devcontainer/devcontainer.json").write_text(
                '{"image":"ghcr.io/owner/repo:wolfi"}')
            for name, code in {
                "git": '#!/bin/sh\nprintf "%s\\n" "$FAKE_SHA"\n',
                "devcontainer": '#!/bin/sh\nprintf "%s\\n" "$@" > "$PUBLISHED"\n',
            }.items():
                (work / name).write_text(code)
                (work / name).chmod(0o755)
            published = work / "published"
            env = dict(os.environ, PATH=temp + ":" + os.environ["PATH"],
                GITHUB_REF="refs/heads/main", GITHUB_EVENT_NAME="push", GITHUB_SHA="a" * 40,
                GITHUB_REPOSITORY="owner/repo", VALIDATION_RESULT="success",
                FAKE_SHA="a" * 40, PUBLISHED=str(published))
            for change in (dict(VALIDATION_RESULT="failure"), dict(VALIDATION_RESULT="skipped"),
                           dict(GITHUB_REF="refs/heads/topic"), dict(FAKE_SHA="c" * 40)):
                result = subprocess.run(["python3", str(SCRIPTS / "publish_template.py")],
                    cwd=work, env=env | change, capture_output=True, check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(published.exists())
            result = subprocess.run(["python3", str(SCRIPTS / "publish_template.py")],
                cwd=work, env=env, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(published.read_text().splitlines(),
                ["templates", "publish", "templates/ror-starter", "--registry", "ghcr.io",
                 "--namespace", "owner/repo/templates"])


if __name__ == "__main__":
    unittest.main()
