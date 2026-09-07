#!/usr/bin/env python3
"""Missing SBOMs and signature failures must not produce a successful gate."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / ".github/scripts/attest_image.py"
DIGEST = "sha256:" + "b" * 64


class AttestationTests(unittest.TestCase):
    def test_sbom_validation_and_exact_digest_signature_failures(self):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            evidence = work / "image-evidence"
            evidence.mkdir()
            (evidence / "context.json").write_text(json.dumps(
                dict(image="ghcr.io/owner/repo", digest=DIGEST, source="a" * 40,
                     release_version="1.2.3")))
            cosign = work / "cosign"
            cosign.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['CALLS'], 'a') as output:
    output.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1].startswith('verify'):
    print('x' * (24 * 1024 * 1024))
print('cosign diagnostic: ' + sys.argv[1], file=sys.stderr)
if sys.argv[1] == os.environ.get('FAIL_COSIGN'):
    sys.exit(9)
''')
            cosign.chmod(0o755)
            calls = work / "calls"
            env = dict(os.environ, RUNNER_TEMP=temp, PATH=temp + ":" + os.environ["PATH"],
                       CALLS=str(calls), IMAGE="ghcr.io/owner/repo", DIGEST=DIGEST,
                       GITHUB_REPOSITORY="owner/repo", GITHUB_REF="refs/heads/main",
                       GITHUB_OUTPUT=str(work / "output"))

            def run(**changes):
                return subprocess.run(["python3", str(SCRIPT)], env=env | changes,
                                      capture_output=True, text=True, check=False)

            self.assertNotEqual(run().returncode, 0)
            self.assertFalse(calls.exists())
            sbom = evidence / "sbom.spdx.json"
            sbom.write_text('{}')
            self.assertNotEqual(run().returncode, 0)
            self.assertFalse(calls.exists())
            sbom.write_text(json.dumps(dict(spdxVersion="SPDX-2.3", SPDXID="SPDXRef-DOCUMENT",
                documentNamespace="https://example.invalid/sbom", packages=[])))
            self.assertNotEqual(run(DIGEST="sha256:" + "c" * 64).returncode, 0)
            self.assertFalse(calls.exists())
            for command in ("sign", "attest", "verify", "verify-attestation"):
                failed = run(FAIL_COSIGN=command)
                self.assertNotEqual(failed.returncode, 0)
                self.assertEqual(len(failed.stdout), 0)
                self.assertIn("cosign diagnostic: " + command, failed.stderr)
                self.assertFalse((work / "output").exists())
            calls.unlink()
            result = run()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(result.stdout), 0)
            self.assertIn("cosign diagnostic: verify-attestation", result.stderr)
            commands = [json.loads(line) for line in calls.read_text().splitlines()]
            self.assertEqual([c[0] for c in commands],
                ["sign", "attest", "attest", "verify", "verify-attestation", "verify-attestation"])
            context = json.loads((evidence / "build-context.json").read_text())
            self.assertEqual(context["source"], "a" * 40)
            self.assertEqual(context["release_version"], "1.2.3")
            self.assertEqual((work / "output").read_text(), "subject_digest=" + DIGEST + "\n")
            for command in commands:
                self.assertIn("ghcr.io/owner/repo@" + DIGEST, command)
                self.assertNotIn("--tlog-upload=false", command)


if __name__ == "__main__":
    unittest.main()
