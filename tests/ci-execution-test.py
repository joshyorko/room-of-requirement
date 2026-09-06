#!/usr/bin/env python3
"""Run CI executables with command-boundary fixtures, never a live daemon."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / ".github/scripts"
SHA = "a" * 40
DIGEST = "sha256:" + "b" * 64

# Docker/devcontainer are external side effects. The tested helpers and shell
# contracts run unchanged; this fixture records exact command boundaries.
FAKE = '''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
name = pathlib.Path(sys.argv[0]).name
with open(os.environ['CALLS'], 'a') as out:
    out.write(json.dumps([name, *args]) + '\\n')
if os.environ.get('FAIL_COMMAND') and os.environ['FAIL_COMMAND'] in ' '.join([name, *args]):
    sys.exit(7)
if name == 'devcontainer':
    print('{"outcome":"success"}')
elif name == 'docker':
    if args[:3] == ['buildx', 'imagetools', 'inspect']:
        if '--raw' in args:
            print('{}')
        elif '{{json .Image}}' in args:
            print(json.dumps({'config': {'Labels': json.loads(os.environ.get('IMAGE_LABELS', '{}'))}}))
        else:
            print(os.environ.get('INSPECT_DIGEST', 'sha256:' + 'b' * 64))
    elif args[:1] == ['run']:
        print('ci-owned-container')
elif name == 'git':
    print(os.environ.get('SOURCE_SHA', 'a' * 40))
'''


class ExecutionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.bin = self.work / "bin"
        self.bin.mkdir()
        for name in ("docker", "devcontainer", "git"):
            target = self.bin / name
            target.write_text(FAKE)
            target.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + ":" + os.environ["PATH"],
                        CALLS=str(self.work / "calls"), RUNNER_TEMP=str(self.work),
                        GITHUB_OUTPUT=str(self.work / "output"), PYTHONDONTWRITEBYTECODE="1")

    def run_script(self, name, *args, **env):
        return subprocess.run([str(SCRIPTS / name), *args], cwd=ROOT, env=self.env | env,
                              text=True, capture_output=True, check=False)

    def calls(self):
        path = self.work / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def request(self, **overrides):
        data = dict(event="pull_request", ref="refs/pull/1/merge", source=SHA,
                    repository="owner/repo", variant="wolfi", run_id="123", run_attempt="1",
                    publish=True, enforce=None, refresh=False, release_version="")
        return json.dumps(data | overrides)

    def test_pr_builds_once_with_features_cache_and_without_publication(self):
        result = self.run_script("build_image.py", REQUEST=self.request())
        self.assertEqual(result.returncode, 0, result.stderr)
        builds = [c for c in self.calls() if c[:2] == ["devcontainer", "build"]]
        self.assertEqual(len(builds), 1)
        self.assertIn("src/wolfi/.devcontainer/devcontainer.json", builds[0])
        self.assertIn("--cache-from", builds[0])
        self.assertNotIn("--cache-to", builds[0])
        self.assertNotIn("--push", builds[0])
        self.assertFalse(any("push" in c or "create" in c for c in self.calls()))

    def test_schedule_refreshes_and_tests_reference_is_registry_digest(self):
        result = self.run_script("build_image.py", REQUEST=self.request(
            event="schedule", ref="refs/heads/main"))
        self.assertEqual(result.returncode, 0, result.stderr)
        build = next(c for c in self.calls() if c[:2] == ["devcontainer", "build"])
        for argument in ("--no-cache", "--push", "--cache-to"):
            self.assertIn(argument, build)
        output = (self.work / "output").read_text()
        self.assertIn("test_image=ghcr.io/owner/repo@" + DIGEST, output)
        self.assertIn(["docker", "pull", "ghcr.io/owner/repo@" + DIGEST], self.calls())

    def test_wrong_checkout_failed_build_or_invalid_digest_stops(self):
        for env in (dict(SOURCE_SHA="c" * 40), dict(FAIL_COMMAND="devcontainer build"),
                    dict(INSPECT_DIGEST="")):
            with self.subTest(env=env):
                result = self.run_script("build_image.py", REQUEST=self.request(
                    event="push", ref="refs/heads/main"), **env)
                self.assertNotEqual(result.returncode, 0)

    def test_branch_candidate_never_writes_shared_cache(self):
        result = self.run_script("build_image.py", REQUEST=self.request(
            event="workflow_dispatch", ref="refs/heads/topic"))
        self.assertEqual(result.returncode, 0, result.stderr)
        build = next(c for c in self.calls() if c[:2] == ["devcontainer", "build"])
        self.assertIn("--push", build)
        self.assertNotIn("--cache-to", build)

    def test_runtime_failure_is_fatal_and_cleans_only_owned_container(self):
        result = self.run_script("runtime-smoke.sh", "ghcr.io/owner/repo@" + DIGEST,
                                 "wolfi", FAIL_COMMAND="docker exec")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(["docker", "rm", "-f", "-v", "ci-owned-container"], self.calls())
        self.assertFalse(any("prune" in c or "ps" in c for c in self.calls()))

    def test_wolfi_runs_docker_and_unprivileged_podman_contracts(self):
        result = self.run_script("runtime-smoke.sh", "local:candidate", "wolfi")
        self.assertEqual(result.returncode, 0, result.stderr)
        executions = [c for c in self.calls() if c[:2] == ["docker", "exec"]]
        self.assertEqual(len(executions), 2)
        self.assertIn("vscode", executions[1])
        self.assertNotIn("--privileged", executions[1])


if __name__ == "__main__":
    unittest.main()
