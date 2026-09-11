#!/usr/bin/env python3
"""Run CI executables with command-boundary fixtures, never a live daemon."""

import json
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import importlib.util

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / ".github/scripts"
SHA = "a" * 40
CONFIG_DIGEST = "sha256:" + "b" * 64
MANIFEST = json.dumps({"schemaVersion": 2, "mediaType": "application/vnd.oci.image.manifest.v1+json",
                       "config": {"digest": CONFIG_DIGEST}, "layers": []})
DIGEST = "sha256:" + hashlib.sha256(MANIFEST.encode()).hexdigest()
LABELS = {"io.ror.publication": "verified-v1", "io.ror.run-id": "123", "io.ror.run-attempt": "1",
          "org.opencontainers.image.source": "https://github.com/owner/repo",
          "org.opencontainers.image.revision": SHA}

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
    if args[0] == 'build' and os.environ.get('BUILDX_NO_DEFAULT_ATTESTATIONS') != '1':
        sys.exit('expected deliberate single-manifest export')
    print('{"outcome":"success"}')
elif name == 'docker':
    if args[:3] == ['buildx', 'imagetools', 'inspect']:
        if '--raw' in args:
            sys.stdout.write(os.environ['MANIFEST'])
        elif '{{json .Image}}' in args:
            key = 'CANDIDATE_LABELS' if '@' in args[3] else 'IMAGE_LABELS'
            print(json.dumps({'config': {'Labels': json.loads(os.environ[key])}}))
        else:
            print(os.environ['INSPECT_DIGEST'])
    elif args[:2] == ['image', 'inspect']:
        if '{{json .Config.Labels}}' in args:
            print(os.environ['CANDIDATE_LABELS'])
        else:
            print(os.environ.get('LOCAL_ID', 'sha256:' + 'b' * 64))
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
                        GITHUB_OUTPUT=str(self.work / "output"), PYTHONDONTWRITEBYTECODE="1",
                        GITHUB_STEP_SUMMARY=str(self.work / "summary"),
                        MANIFEST=MANIFEST, INSPECT_DIGEST=DIGEST,
                        CANDIDATE_LABELS=json.dumps(LABELS), IMAGE_LABELS=json.dumps(LABELS))

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
                    dict(INSPECT_DIGEST=""), dict(LOCAL_ID="sha256:" + "d" * 64)):
            with self.subTest(env=env):
                result = self.run_script("build_image.py", REQUEST=self.request(
                    event="push", ref="refs/heads/main"), **env)
                self.assertNotEqual(result.returncode, 0)

    def test_missing_or_wrong_pulled_candidate_metadata_is_rejected(self):
        for labels in ({}, LABELS | {"io.ror.run-id": "124"},
                       LABELS | {"org.opencontainers.image.revision": "c" * 40}):
            result = self.run_script("build_image.py", REQUEST=self.request(
                event="push", ref="refs/heads/main"), CANDIDATE_LABELS=json.dumps(labels))
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

    def test_runtime_uses_anonymous_volumes_for_both_feature_graph_stores(self):
        for variant in ("ubuntu-noble", "debian-trixie", "wolfi"):
            with self.subTest(variant=variant):
                result = self.run_script("runtime-smoke.sh", "local:candidate", variant)
                self.assertEqual(result.returncode, 0, result.stderr)
                run = [c for c in self.calls() if c[:2] == ["docker", "run"] and "-d" in c][-1]
                mounts = []
                for i, arg in enumerate(run[:-1]):
                    if arg != "--mount":
                        continue
                    mount = {}
                    for field in run[i + 1].split(","):
                        key, separator, value = field.partition("=")
                        mount[key] = value if separator else True
                    mounts.append(mount)
                for target in ("/var/lib/docker", "/var/lib/containerd"):
                    self.assertIn({"type": "volume", "target": target}, mounts)

    def test_wolfi_runs_docker_and_unprivileged_podman_contracts(self):
        result = self.run_script("runtime-smoke.sh", "local:candidate", "wolfi")
        self.assertEqual(result.returncode, 0, result.stderr)
        executions = [c for c in self.calls() if c[:2] == ["docker", "exec"]]
        self.assertEqual(len(executions), 6)
        self.assertIn("vscode", executions[1])
        self.assertNotIn("--privileged", executions[1])
        self.assertIn("root", executions[2])
        self.assertIn("/ror-source/.github/scripts/home-smoke.sh", executions[2])
        self.assertIn("root", executions[3])
        self.assertTrue(any("ghostty-smoke.sh" in argument for argument in executions[3]))
        self.assertNotIn("-i", executions[3])
        self.assertIn("-t", executions[3])
        self.assertEqual(executions[3][executions[3].index("-e") + 1], "TERM=xterm-ghostty")
        self.assertIn("vscode", executions[4])
        self.assertTrue(any("ghostty-smoke.sh" in argument for argument in executions[4]))
        self.assertNotIn("-i", executions[4])
        self.assertIn("-t", executions[4])
        self.assertEqual(executions[4][executions[4].index("-e") + 1], "TERM=xterm-ghostty")
        run = next(c for c in self.calls() if c[:2] == ["docker", "run"])
        self.assertIn("type=bind,source=" + str(ROOT) + ",target=/ror-source,readonly", run)

    def test_wolfi_daemon_probe_owns_a_separate_container_on_the_same_image(self):
        image = "ghcr.io/owner/repo@" + DIGEST
        result = self.run_script("runtime-smoke.sh", image, "wolfi")
        self.assertEqual(result.returncode, 0, result.stderr)
        runs = [c for c in self.calls() if c[:2] == ["docker", "run"]]
        self.assertEqual(len(runs), 2)
        primary, probe = runs
        self.assertEqual(primary[-3:], [image, "sleep", "infinity"])
        self.assertEqual(probe[-3:], [image, "/ror-docker-image-smoke.sh", "--in-container"])
        self.assertIn("--rm", probe)
        self.assertIn("--privileged", probe)
        for option, value in (("--entrypoint", "bash"), ("--pull", "never"), ("--network", "none")):
            self.assertEqual(probe[probe.index(option) + 1], value)
        self.assertIn("type=bind,source=" + str(ROOT / "src/common/scripts/ror-docker-start.sh")
                      + ",target=/usr/local/bin/ror-docker-start.sh,readonly", probe)
        self.assertFalse(any(c[:2] == ["docker", "exec"] and "runtime-docker-image-smoke.sh" in " ".join(c)
                             for c in self.calls()))
        self.assertIn(["docker", "rm", "-f", "-v", "ci-owned-container"], self.calls())

    def test_wolfi_image_regressions_are_required_and_fail_closed(self):
        for suite in ("runtime-native-smoke.sh", "runtime-docker-image-smoke.sh"):
            with self.subTest(suite=suite):
                (self.work / "calls").unlink(missing_ok=True)
                result = self.run_script("runtime-smoke.sh", "local:candidate", "wolfi",
                                         FAIL_COMMAND=suite)
                self.assertEqual(result.returncode, 7, result.stderr)
                execution = next(c for c in self.calls() if suite in " ".join(c))
                self.assertIn("--in-container", execution)
                self.assertIn(["docker", "rm", "-f", "-v", "ci-owned-container"], self.calls())

    def test_required_privileged_home_contract_failure_fails_runtime_gate(self):
        result = self.run_script("runtime-smoke.sh", "local:candidate", "ubuntu-noble",
                                 FAIL_COMMAND="home-smoke.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(["docker", "rm", "-f", "-v", "ci-owned-container"], self.calls())

    def test_ghostty_contract_runs_for_every_stream(self):
        for variant in ("ubuntu-noble", "debian-trixie", "wolfi"):
            with self.subTest(variant=variant):
                (self.work / "calls").unlink(missing_ok=True)
                result = self.run_script("runtime-smoke.sh", "local:candidate", variant)
                self.assertEqual(result.returncode, 0, result.stderr)
                executions = [c for c in self.calls() if c[:2] == ["docker", "exec"]]
                ghostty_calls = [c for c in executions if any("ghostty-smoke.sh" in argument for argument in c)]
                self.assertTrue(ghostty_calls)
                self.assertEqual(len(ghostty_calls), 2)

    def test_ghostty_failure_cleans_the_owned_container(self):
        for variant in ("ubuntu-noble", "debian-trixie", "wolfi"):
            with self.subTest(variant=variant):
                result = self.run_script("runtime-smoke.sh", "local:candidate", variant,
                                         FAIL_COMMAND="ghostty-smoke.sh")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(["docker", "rm", "-f", "-v", "ci-owned-container"], self.calls())

    def promotion(self, **changes):
        data = json.loads(self.request(event="push", ref="refs/heads/main", enforce=True))
        data.update(digest=DIGEST, **changes)
        path = self.work / "context.json"
        path.write_text(json.dumps(data))
        return path

    def test_promotion_copies_the_verified_digest_without_rebuilding(self):
        path = self.promotion()
        needs = {k: {"result": "success", "outputs": {"subject_digest": DIGEST}}
                 for k in ("verify", "attest", "provenance")}
        result = self.run_script("promote_image.py", str(path), NEEDS=json.dumps(needs))
        self.assertEqual(result.returncode, 0, result.stderr)
        writes = [c for c in self.calls() if "create" in c]
        self.assertEqual(writes, [["docker", "buildx", "imagetools", "create",
            "--prefer-index=false", "--tag", "ghcr.io/owner/repo:wolfi",
            "--tag", "ghcr.io/owner/repo:secure", "ghcr.io/owner/repo@" + DIGEST]])
        self.assertFalse(any(c[0] == "devcontainer" or "build" in c for c in self.calls()))

    def test_promotion_failure_paths_never_write_a_registry_tag(self):
        path = self.promotion()
        needs = {k: {"result": "success", "outputs": {"subject_digest": DIGEST}}
                 for k in ("verify", "attest", "provenance")}
        cases = [dict(SOURCE_SHA="c" * 40), dict(FAIL_COMMAND="git fetch"),
                 dict(FAIL_COMMAND="docker buildx imagetools inspect"),
                 dict(IMAGE_LABELS=json.dumps(LABELS | {"io.ror.run-id": "124"})),
                 dict(IMAGE_LABELS=json.dumps(LABELS | {"io.ror.run-attempt": "2"})),
                 dict(CANDIDATE_LABELS="{}"),
                 dict(IMAGE_LABELS=json.dumps({"io.ror.publication": "verified-v1"})),
                 dict(NEEDS=json.dumps(needs | {"attest": {"result": "failure"}}))]
        cases.append(dict(NEEDS=json.dumps(needs | {"provenance": {
            "result": "success", "outputs": {"subject_digest": "sha256:" + "d" * 64}}})))
        for env in cases:
            with self.subTest(env=env):
                result = self.run_script("promote_image.py", str(path),
                    **({"NEEDS": json.dumps(needs)} | env))
                self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any("create" in c for c in self.calls()))


class GitSourceTests(unittest.TestCase):
    """Actual git commits/annotated tags, with only GitHub release metadata faked."""

    def test_release_tag_peels_to_an_older_main_commit_and_detects_divergence(self):
        import sys
        from unittest.mock import patch
        sys.path.insert(0, str(SCRIPTS))
        spec = importlib.util.spec_from_file_location("promotion", SCRIPTS / "promote_image.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp)

            def git(*args):
                return subprocess.check_output(["git", "-C", str(repo), *args],
                    text=True, stderr=subprocess.DEVNULL).strip()

            git("init", "-b", "main")
            git("config", "user.email", "ci@example.invalid")
            git("config", "user.name", "CI Fixture")
            git("commit", "--allow-empty", "-m", "released")
            source = git("rev-parse", "HEAD")
            git("tag", "-a", "v1.2.3", "-m", "release")
            git("commit", "--allow-empty", "-m", "new main")
            git("remote", "add", "origin", str(repo))
            real_capture = module.capture

            def metadata(*args):
                if args[:3] == ("gh", "release", "view"):
                    return json.dumps(dict(tagName="v1.2.3", isDraft=False, isPrerelease=False))
                if args[:2] == ("gh", "api"):
                    return json.dumps(dict(tag_name="v1.2.3"))
                return real_capture(*args)

            previous = Path.cwd()
            try:
                os.chdir(repo)
                with patch.object(module, "capture", side_effect=metadata):
                    facts = module.source_facts(dict(release_version="1.2.3", source=source,
                                                     repository="owner/repo"))
                    self.assertEqual(facts["tag_sha"], source)
                    self.assertTrue(facts["main_ancestor"])
                    self.assertNotEqual(facts["main_sha"], source)
                    git("checkout", "--orphan", "other")
                    git("commit", "--allow-empty", "-m", "unrelated")
                    facts = module.source_facts(dict(release_version="1.2.3",
                        source=git("rev-parse", "HEAD"), repository="owner/repo"))
                    self.assertFalse(facts["main_ancestor"])
            finally:
                os.chdir(previous)


if __name__ == "__main__":
    unittest.main()
