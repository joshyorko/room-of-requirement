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
from image_identity import (local_identity, registry_identity, scan_identity,
                            validate_local_image, verified_subject)


class IdentityTests(unittest.TestCase):
    def test_classic_local_inspect_uses_id_for_docker_and_config_identity(self):
        config = "sha256:" + "1" * 64
        self.assertEqual(local_identity({"Id": config}),
                         dict(mode="local", docker_id=config, config_digest=config))

    def test_containerd_local_inspect_requires_single_manifest_and_config_annotation(self):
        docker_id = "sha256:" + "1" * 64
        config = "sha256:" + "2" * 64
        image = {"Id": docker_id, "Descriptor": {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "digest": docker_id, "annotations": {"config.digest": config}}}
        self.assertEqual(local_identity(image),
                         dict(mode="local", docker_id=docker_id, config_digest=config))

    def test_local_inspect_rejects_missing_or_malformed_descriptor_identity(self):
        docker_id = "sha256:" + "1" * 64
        valid = {"mediaType": "application/vnd.oci.image.manifest.v1+json",
                 "digest": docker_id, "annotations": {"config.digest": "sha256:" + "2" * 64}}
        for descriptor in (
                valid | {"annotations": {}},
                valid | {"annotations": {"config.digest": "bad"}},
                valid | {"digest": "sha256:" + "3" * 64},
                valid | {"mediaType": "application/vnd.oci.image.index.v1+json"},
                valid | {"annotations": []},
                []):
            with self.subTest(descriptor=descriptor):
                with self.assertRaises(ValueError):
                    local_identity({"Id": docker_id, "Descriptor": descriptor})
        for image in ({}, {"Id": "bad"}, {"Id": docker_id, "Descriptor": "bad"}):
            with self.subTest(image=image):
                with self.assertRaises(ValueError):
                    local_identity(image)

    def test_pulled_containerd_descriptor_can_omit_config_annotation(self):
        docker_id = "sha256:" + "3" * 64
        config = "sha256:" + "2" * 64
        manifest = docker_id
        identity = dict(mode="registry", manifest_digest=manifest, config_digest=config)
        image = {"Id": docker_id, "Descriptor": {
            "mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": manifest}}
        self.assertEqual(validate_local_image(image, identity), docker_id)
        for descriptor in (
                image["Descriptor"] | {"digest": "sha256:" + "4" * 64},
                image["Descriptor"] | {"mediaType": "application/vnd.oci.image.index.v1+json"},
                image["Descriptor"] | {"annotations": {"config.digest": "sha256:" + "5" * 64}}):
            with self.subTest(descriptor=descriptor):
                with self.assertRaises(ValueError):
                    validate_local_image({"Id": docker_id, "Descriptor": descriptor}, identity)

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

    def test_local_runtime_uses_docker_id_and_rejects_config_digest_or_replay(self):
        docker_id = "sha256:" + "1" * 64
        config = "sha256:" + "2" * 64
        identity = dict(mode="local", docker_id=docker_id, config_digest=config)
        scan = dict(subject=identity, enforce=True, critical_fixed=0)
        plan = dict(publish=False, enforce=True, test_image=docker_id)
        self.assertEqual(verified_subject(plan, identity, scan), "")
        for wrong_image in (config, "sha256:" + "3" * 64):
            with self.subTest(test_image=wrong_image):
                with self.assertRaises(ValueError):
                    verified_subject(plan | {"test_image": wrong_image}, identity, scan)
        with self.assertRaises(ValueError):
            verified_subject(plan, identity | {"docker_id": "sha256:" + "3" * 64}, scan)

    def test_provenance_records_subject_only_after_signed_claims_verify(self):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            cosign = work / "cosign"
            cosign.write_text('''#!/usr/bin/env python3
import os, sys
assert sys.argv[1] == 'verify-attestation'
assert '--check-claims' in sys.argv
assert '--new-bundle-format=false' in sys.argv
assert '--insecure-ignore-tlog' not in sys.argv
assert '--insecure-ignore-tlog=true' not in sys.argv
assert '--certificate-identity' in sys.argv
assert '--certificate-oidc-issuer' in sys.argv
assert sys.argv[-1] == 'ghcr.io/owner/repo@sha256:' + '1' * 64
print('x' * (24 * 1024 * 1024))
print('cosign provenance diagnostic', file=sys.stderr)
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
                self.assertEqual(len(result.stdout), 0)
                self.assertFalse(output.exists())
            result = subprocess.run(["python3", str(script)], env=env, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(result.stdout), 0)
            self.assertIn(b"cosign provenance diagnostic", result.stderr)
            self.assertEqual(output.read_text(), "subject_digest=sha256:" + "1" * 64 + "\n")


if __name__ == "__main__":
    unittest.main()
