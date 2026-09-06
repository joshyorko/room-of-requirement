#!/usr/bin/env python3
"""Execute CI policy/report helpers; no registry, daemon, or GitHub writes."""

import copy
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


def invoke(script, *args, data=None, env=None):
    return subprocess.run(
        ["python3", str(SCRIPTS / script), *args],
        input=json.dumps(data) if data is not None else None,
        text=True, capture_output=True, env={**os.environ, **(env or {})}, check=False,
    )


class PolicyTests(unittest.TestCase):
    def context(self, **overrides):
        data = dict(event="schedule", ref="refs/heads/main", source=SHA,
                    repository="Owner/Repo", variant="ubuntu-noble", run_id="123",
                    run_attempt="1", publish=True, enforce=None, refresh=True,
                    release_version="")
        data.update(overrides)
        return invoke("ci_policy.py", "context", data=data)

    def test_absent_true_false_policy_preserves_explicit_false(self):
        for raw, expected in ((None, True), ("", True), (True, True), (False, False),
                              ("true", True), ("false", False)):
            with self.subTest(raw=raw):
                result = self.context(enforce=raw)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIs(json.loads(result.stdout)["enforce"], expected)

    def test_invalid_policy_is_not_an_opt_out(self):
        for raw in (0, "FALSE", "no", {}, []):
            self.assertNotEqual(self.context(enforce=raw).returncode, 0)

    def test_pr_cannot_publish_even_when_requested(self):
        result = self.context(event="pull_request", ref="refs/pull/7/merge", publish=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(json.loads(result.stdout)["publish"])

    def test_unique_candidate_and_shared_variant_cache(self):
        result = self.context()
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["candidate"], "ghcr.io/owner/repo:candidate-ubuntu-noble-123-1")
        self.assertEqual(plan["cache_scope"], "ror-ubuntu-noble-amd64")
        self.assertNotEqual(plan["candidate"], json.loads(self.context(run_attempt="2").stdout)["candidate"])

    def promotion(self, **overrides):
        data = dict(event="push", ref="refs/heads/main", source=SHA, main_sha=SHA,
                    repository="owner/repo", variant="ubuntu-noble", run_id="123",
                    run_attempt="1", publish=True, enforce=True, digest=DIGEST,
                    release_version="", gates={name: "success" for name in
                    ("verify", "attest", "provenance")})
        data.update(overrides)
        return invoke("ci_policy.py", "promotion", data=data)

    def test_current_main_gets_only_owned_aliases(self):
        result = self.promotion()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout),
                         ["ubuntu-noble", "ubuntu-noble-dind", "latest", "codespaces"])
        self.assertEqual(json.loads(self.promotion(variant="wolfi").stdout), ["wolfi", "secure"])

    def test_failed_skipped_cancelled_missing_gates_never_promote(self):
        for gate in ("verify", "attest", "provenance"):
            for outcome in ("failure", "skipped", "cancelled", None):
                gates = dict(verify="success", attest="success", provenance="success")
                gates[gate] = outcome
                with self.subTest(gate=gate, outcome=outcome):
                    self.assertNotEqual(self.promotion(gates=gates).returncode, 0)
        self.assertNotEqual(self.promotion(gates={}).returncode, 0)

    def test_untrusted_stale_or_policy_override_never_promotes(self):
        for changes in (dict(ref="refs/heads/topic", event="workflow_dispatch"),
                        dict(event="pull_request"), dict(source="c" * 40),
                        dict(digest=""), dict(enforce=False), dict(publish=False),
                        dict(variant="../wolfi"), dict(event="workflow_run")):
            with self.subTest(changes=changes):
                self.assertNotEqual(self.promotion(**changes).returncode, 0)

    def test_released_source_can_precede_current_main(self):
        release = dict(source="c" * 40, release_version="1.2.3", tag_sha="c" * 40,
                       main_ancestor=True, latest_release="v1.2.3", release_tag="v1.2.3")
        result = self.promotion(**release)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), ["v1.2.3", "v1.2", "v1"])
        self.assertEqual(json.loads(self.promotion(**release, variant="wolfi").stdout),
                         ["v1.2.3-wolfi", "v1.2-wolfi", "v1-wolfi"])
        for changes in (dict(tag_sha=SHA), dict(main_ancestor=False),
                        dict(latest_release="v1.2.4"), dict(release_tag="v1.2.4"),
                        dict(ref="refs/heads/topic"), dict(release_version="1.2.3-rc.1")):
            with self.subTest(changes=changes):
                self.assertNotEqual(self.promotion(**(release | changes)).returncode, 0)
        self.assertEqual(self.promotion(**release, ref="refs/tags/v1.2.3").returncode, 0)


class ScanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.fixture = json.loads((ROOT / "tests/ci-fixtures/grype-image.json").read_text())
        # Upstream's presenter-only second match has a zero-value fix state.
        # Use the actual scanner's unknown state for valid-report tests.
        self.fixture["matches"][1]["vulnerability"]["fix"]["state"] = "unknown"

    def scan(self, report, policy="null", outcome="success"):
        if report is not None:
            (self.path / "scan.json").write_text(json.dumps(report))
        return invoke("scan_report.py", str(self.path / "scan.json"),
                      "--enforce", policy, "--scanner-outcome", outcome,
                      "--sarif", str(self.path / "scan.sarif"),
                      "--summary", str(self.path / "summary.json"))

    def test_upstream_grype_json_counts_real_severity(self):
        result = self.scan(self.fixture)
        self.assertEqual(result.returncode, 0, result.stderr)
        summary = json.loads((self.path / "summary.json").read_text())
        self.assertEqual(summary["counts"]["low"], 1)
        self.assertEqual(summary["counts"]["critical"], 1)

    def test_fixed_critical_blocks_by_default_and_report_survives(self):
        match = self.fixture["matches"][0]
        match["vulnerability"]["severity"] = "Critical"
        self.fixture["matches"].append(copy.deepcopy(match))
        result = self.scan(self.fixture)
        self.assertNotEqual(result.returncode, 0)
        summary = json.loads((self.path / "summary.json").read_text())
        self.assertEqual(summary["critical_fixed"], 1)
        sarif = json.loads((self.path / "scan.sarif").read_text())
        self.assertEqual(len(sarif["runs"][0]["results"]), 1)
        self.assertEqual(sarif["runs"][0]["results"][0]["ruleId"], "CVE-1999-0001")
        self.assertEqual(self.scan(self.fixture, policy="false").returncode, 0)

    def test_high_and_unfixed_critical_do_not_block(self):
        self.fixture["matches"][0]["vulnerability"]["severity"] = "High"
        vuln = self.fixture["matches"][1]["vulnerability"]
        vuln.update(severity="Critical", fix={"state": "not-fixed", "versions": []})
        self.assertEqual(self.scan(self.fixture).returncode, 0)

    def test_empty_valid_report_passes(self):
        self.fixture["matches"] = []
        self.assertEqual(self.scan(self.fixture).returncode, 0)

    def test_presenter_zero_value_fix_state_is_rejected(self):
        raw = json.loads((ROOT / "tests/ci-fixtures/grype-image.json").read_text())
        self.assertNotEqual(self.scan(raw, policy="false").returncode, 0)

    def test_execution_error_missing_output_and_malformed_reports_fail_even_opt_out(self):
        self.assertNotEqual(self.scan(None, policy="false").returncode, 0)
        self.assertNotEqual(self.scan(self.fixture, policy="false", outcome="failure").returncode, 0)
        for report in ({}, {"matches": []}, {"matches": None}, {"matches": [{}]}, []):
            self.assertNotEqual(self.scan(report, policy="false").returncode, 0)
        for bad in ("", "catastrophic"):
            self.fixture["matches"][0]["vulnerability"]["severity"] = bad
            self.assertNotEqual(self.scan(self.fixture, policy="false").returncode, 0)


if __name__ == "__main__":
    unittest.main()
