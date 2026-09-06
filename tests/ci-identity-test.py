#!/usr/bin/env python3
"""Verify the supported manifest/config relationship without equating their IDs."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / ".github/scripts"))
from image_identity import registry_identity, scan_identity, verified_subject


class IdentityTests(unittest.TestCase):
    def test_single_manifest_binds_distinct_config_digest(self):
        config = "sha256:" + "1" * 64
        manifest = dict(schemaVersion=2, mediaType="application/vnd.oci.image.manifest.v1+json",
                        config={"digest": config}, layers=[])
        raw = json.dumps(manifest).encode()
        digest = "sha256:" + hashlib.sha256(raw).hexdigest()
        identity = registry_identity(raw, digest)
        self.assertEqual(identity, dict(mode="registry", manifest_digest=digest, config_digest=config))
        self.assertNotEqual(digest, config)
        source = dict(type="image", target=dict(imageID=config, manifestDigest=digest,
                                                mediaType=manifest["mediaType"]))
        self.assertEqual(scan_identity(source, identity), identity)
        source["target"]["imageID"] = digest
        with self.assertRaises(ValueError):
            scan_identity(source, identity)
        with self.assertRaises(ValueError):
            registry_identity(raw, config)

    def test_index_is_rejected_even_if_its_child_has_the_expected_platform(self):
        raw = json.dumps(dict(schemaVersion=2, mediaType="application/vnd.oci.image.index.v1+json",
            manifests=[dict(digest="sha256:" + "2" * 64, platform=dict(os="linux", architecture="amd64"))])).encode()
        with self.assertRaises(ValueError):
            registry_identity(raw, "sha256:" + hashlib.sha256(raw).hexdigest())

    def test_final_verification_rejects_cross_digest_scan_and_runtime_replay(self):
        digest = "sha256:" + "1" * 64
        identity = dict(mode="registry", manifest_digest=digest, config_digest="sha256:" + "2" * 64)
        plan = dict(publish=True, enforce=True, image="ghcr.io/owner/repo", digest=digest,
                    test_image="ghcr.io/owner/repo@" + digest)
        scan = dict(subject=identity, enforce=True, critical_fixed=0)
        self.assertEqual(verified_subject(plan, identity, scan), digest)
        for bad in (scan | {"subject": identity | {"manifest_digest": "sha256:" + "3" * 64}},
                    scan | {"enforce": False}, scan | {"critical_fixed": 1}):
            with self.assertRaises(ValueError):
                verified_subject(plan, identity, bad)
        with self.assertRaises(ValueError):
            verified_subject(plan | {"test_image": "ghcr.io/owner/repo@sha256:" + "3" * 64}, identity, scan)

    def test_provenance_records_subject_only_after_signed_claims_verify(self):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            cosign = work / "cosign"
            cosign.write_text('''#!/usr/bin/env python3
import os, sys
assert sys.argv[1] == 'verify-attestation'
assert '--check-claims' in sys.argv
assert sys.argv[-1] == 'ghcr.io/owner/repo@sha256:' + '1' * 64
sys.exit(int(os.environ.get('FAIL_COSIGN', '0')))
''')
            cosign.chmod(0o755)
            output = work / "output"
            env = dict(os.environ, PATH=temp + ":" + os.environ["PATH"],
                       GITHUB_OUTPUT=str(output), IMAGE="ghcr.io/owner/repo",
                       DIGEST="sha256:" + "1" * 64, GENERATOR_RESULT="success")
            script = Path(__file__).resolve().parents[1] / ".github/scripts/verify_provenance.py"
            for changes in (dict(FAIL_COSIGN="9"), dict(GENERATOR_RESULT="failure"),
                            dict(GENERATOR_RESULT="skipped"), dict(DIGEST="sha256:" + "2" * 64)):
                result = subprocess.run(["python3", str(script)], env=env | changes,
                                        capture_output=True, check=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(output.exists())
            result = subprocess.run(["python3", str(script)], env=env, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(output.read_text(), "subject_digest=sha256:" + "1" * 64 + "\n")


if __name__ == "__main__":
    unittest.main()
