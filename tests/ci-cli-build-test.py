#!/usr/bin/env python3
"""Run pinned Dev Containers CLI; record Docker commands without a daemon/build."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / ".github/scripts"
sys.path.insert(0, str(SCRIPTS))

RECORDER = '''#!/usr/bin/env python3
import hashlib, json, os, pathlib, sys
args = sys.argv[1:]
state_path = pathlib.Path(os.environ['CI_DOCKER_STATE'])
state = json.loads(state_path.read_text()) if state_path.exists() else {'labels': {}, 'builds': []}
if args[:2] == ['buildx', 'version']:
    print('github.com/docker/buildx v0.30.0 abc')
elif args[:2] == ['buildx', 'build'] or args[:1] == ['build']:
    labels = {}
    for index, value in enumerate(args):
        if value == '--label':
            key, value = args[index + 1].split('=', 1)
            labels[key] = value
    state['labels'] = labels
    state['builds'].append(args)
    if '-f' in args:
        state['dockerfile'] = pathlib.Path(args[args.index('-f') + 1]).read_text()
    state_path.write_text(json.dumps(state))
elif args[:2] == ['image', 'inspect'] or args[:3] == ['buildx', 'imagetools', 'inspect']:
    config = {'architecture': 'amd64', 'os': 'linux', 'config': {'User': 'root', 'Env': ['PATH=/usr/bin'], 'Labels': state['labels']}}
    config_raw = json.dumps(config).encode()
    config_id = 'sha256:' + hashlib.sha256(config_raw).hexdigest()
    manifest = {'schemaVersion': 2, 'mediaType': 'application/vnd.oci.image.manifest.v1+json',
                'config': {'digest': config_id}, 'layers': []}
    raw = json.dumps(manifest)
    if '--raw' in args:
        sys.stdout.write(raw)
    elif '{{.Manifest.Digest}}' in args:
        print('sha256:' + hashlib.sha256(raw.encode()).hexdigest())
    elif '{{.Id}}' in args:
        print(config_id)
    elif '{{json .Config.Labels}}' in args:
        print(json.dumps(state['labels']))
    elif '{{json .Image}}' in args:
        print(json.dumps(config))
    else:
        print(json.dumps([{'Id': config_id, 'Config': config['config'], 'Architecture': 'amd64', 'Os': 'linux'}]))
elif args[:1] == ['version']:
    print('29.0.0')
elif args[:1] == ['inspect']:
    print('[]')
elif args[:1] != ['pull']:
    sys.exit('Unexpected Docker command: ' + repr(args))
'''


class CliBuildTests(unittest.TestCase):
    def setUp(self):
        self.cli = shutil.which("devcontainer")
        self.assertIsNotNone(self.cli, "Install @devcontainers/cli@0.89.0 for this required probe")
        self.assertEqual(subprocess.check_output([self.cli, "--version"], text=True).strip(), "0.89.0")
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / "src/wolfi/.devcontainer"
        self.config.mkdir(parents=True)
        (self.config / "Dockerfile").write_text("FROM scratch\n")
        (self.config / "devcontainer-lock.json").write_text('{"features":{}}')
        feature = self.root / ".devcontainer/feature"
        feature.mkdir(parents=True)
        (feature / "devcontainer-feature.json").write_text('{"id":"probe","version":"1.0.0","name":"Probe"}')
        (feature / "install.sh").write_text('#!/bin/sh\ntrue\n')
        (self.root / "bin").mkdir()
        docker = self.root / "bin/docker"
        docker.write_text(RECORDER)
        docker.chmod(0o755)
        for args in (("init", "-b", "main"), ("config", "user.name", "CI Fixture"),
                     ("config", "user.email", "ci@example.invalid"), ("commit", "--allow-empty", "-m", "fixture")):
            subprocess.run(["git", "-C", str(self.root), *args], capture_output=True, check=True)
        self.source = subprocess.check_output(["git", "-C", str(self.root), "rev-parse", "HEAD"], text=True).strip()
        self.env = dict(os.environ, PATH=str(self.root / "bin") + ":" + str(Path(self.cli).parent) + ":" + os.environ["PATH"],
                        CI_DOCKER_STATE=str(self.root / "state.json"), RUNNER_TEMP=str(self.root),
                        GITHUB_OUTPUT=str(self.root / "output"), PYTHONDONTWRITEBYTECODE="1")

    def build(self, with_feature, run_id="123"):
        config = dict(build=dict(dockerfile="Dockerfile", context="../../.."))
        if with_feature:
            config["features"] = {"../../../.devcontainer/feature": {}}
        (self.config / "devcontainer.json").write_text(json.dumps(config))
        state_path = self.root / "state.json"
        state_path.unlink(missing_ok=True)
        request = dict(event="schedule", ref="refs/heads/main", source=self.source,
                       repository="owner/repo", variant="wolfi", run_id=run_id, run_attempt="1",
                       publish=True, enforce=True, refresh=False, release_version="")
        result = subprocess.run([str(SCRIPTS / "build_image.py")], cwd=self.root,
                                env=self.env | {"REQUEST": json.dumps(request)},
                                text=True, capture_output=True, timeout=60, check=False)
        self.assertEqual(result.returncode, 0, result.stderr[-4000:])
        return json.loads(state_path.read_text()), request

    def test_actual_cli_places_run_metadata_on_its_single_final_build_with_and_without_features(self):
        for feature in (False, True):
            with self.subTest(feature=feature):
                state, _ = self.build(feature)
                self.assertEqual(len(state["builds"]), 1)
                expected = {"io.ror.publication": "verified-v1", "io.ror.run-id": "123", "io.ror.run-attempt": "1",
                            "org.opencontainers.image.source": "https://github.com/owner/repo",
                            "org.opencontainers.image.revision": self.source}
                for key, value in expected.items():
                    self.assertEqual(state["labels"].get(key), value)
                for flag in ("--no-cache", "--pull", "--cache-to", "--push"):
                    self.assertIn(flag, state["builds"][0])
                if feature:
                    self.assertIn("dev_containers_target_stage", state["builds"][0])
                    self.assertIn("install.sh", state["dockerfile"])
                receipt = json.loads((self.root / "image-evidence/metadata.json").read_text())
                self.assertEqual(receipt, state["labels"])

    def test_actual_cli_metadata_rejects_same_source_out_of_order_promotion(self):
        older, plan = self.build(True, "123")
        newer, _ = self.build(True, "124")
        spec = importlib.util.spec_from_file_location("ci_promote", SCRIPTS / "promote_image.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        plan["digest"] = "sha256:" + "a" * 64
        gates = {k: {"status": "success", "digest": plan["digest"]} for k in ("verify", "attest", "provenance")}

        def registry(reference):
            labels = older["labels"] if "@" in reference else newer["labels"]
            return {"config": {"Labels": labels}}

        with patch.object(module, "source_facts", return_value={"main_sha": self.source}), \
                patch.object(module, "existing_image", side_effect=registry), \
                patch.object(module.subprocess, "run", side_effect=AssertionError("must not mutate registry")):
            with self.assertRaisesRegex(ValueError, "newer run"):
                module.promote(plan, gates)


if __name__ == "__main__":
    unittest.main()
