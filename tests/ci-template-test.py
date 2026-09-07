#!/usr/bin/env python3
"""Starter application retains lifecycle/features and only isolates CI storage."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
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

    def test_disposable_workspace_with_runner_1001_and_candidate_1000_is_writable_and_cleanable(self):
        # Real Linux permission checks under distinct UIDs, without Docker or real user files.
        with tempfile.TemporaryDirectory(prefix="ror-ci-template-permissions-") as temp:
            root = Path(temp)
            root.chmod(0o1777)  # Match /tmp: the runner may remove its own workspace.
            helpers = root / "helpers"
            helpers.mkdir(mode=0o755)
            for name in ("template_smoke.py", "ci_policy.py"):
                shutil.copyfile(SCRIPTS / name, helpers / name)
            work = root / "project"
            outside = root / "outside"
            outside.write_text("outside the disposable project")
            outside.chmod(0o640)
            outside_before = (outside.stat().st_uid, outside.stat().st_mode, os.listxattr(outside))
            subprocess.run(["sudo", "-n", "install", "-d", "-o", "1001", "-g", "1001",
                            "-m", "0700", str(work)], check=True)

            def as_uid(uid, script):
                launcher = ("import os,sys; uid=int(sys.argv.pop(1)); script=sys.argv.pop(1); "
                            "os.setgroups([]); os.setgid(uid); os.setuid(uid); exec(script)")
                return subprocess.run(["sudo", "-n", sys.executable, "-c", launcher, str(uid), script,
                    str(work), str(helpers)], text=True, capture_output=True, check=False)

            try:
                setup = as_uid(1001, """
import os, pathlib, sys
root = pathlib.Path(sys.argv[1])
os.umask(0o077)
(root / '.devcontainer').mkdir()
(root / '.devcontainer/devcontainer.json').write_text('{}')
(root / 'run.sh').write_text('#!/bin/sh\\ntrue\\n')
(root / 'run.sh').chmod(0o700)
(root / 'outside-link').symlink_to(root.parent / 'outside')
""")
                self.assertEqual(setup.returncode, 0, setup.stderr)
                write_probe = """
import os, pathlib, sys
os.chdir(sys.argv[1])
pathlib.Path('.devcontainer/devcontainer.json').write_text('{"edited":true}')
pathlib.Path('generated/nested').mkdir(parents=True)
pathlib.Path('generated/nested/output').write_text('candidate output')
assert os.access('run.sh', os.X_OK)
"""
                self.assertNotEqual(as_uid(1000, write_probe).returncode, 0)
                prepared = as_uid(1001, """
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[2])
import template_smoke
template_smoke.prepare_workspace(Path(sys.argv[1]), 1000)
""")
                self.assertEqual(prepared.returncode, 0, prepared.stderr)
                self.assertEqual((outside.stat().st_uid, outside.stat().st_mode, os.listxattr(outside)),
                                 outside_before)
                written = as_uid(1000, write_probe)
                self.assertEqual(written.returncode, 0, written.stderr)
                denied = as_uid(1002, "import os,sys; os.chdir(sys.argv[1])")
                self.assertNotEqual(denied.returncode, 0)
                cleaned = as_uid(1001, """
import pathlib, shutil, sys
root = pathlib.Path(sys.argv[1])
assert root.stat().st_uid == 1001
assert (root / 'generated/nested/output').stat().st_uid == 1000
shutil.rmtree(root)
""")
                self.assertEqual(cleaned.returncode, 0, cleaned.stderr)
                self.assertFalse(work.exists())
            finally:
                # Only this test's freshly-created workspace; needed when testing the red path.
                subprocess.run(["sudo", "-n", "rm", "-rf", "--", str(work)], check=True)


if __name__ == "__main__":
    unittest.main()
