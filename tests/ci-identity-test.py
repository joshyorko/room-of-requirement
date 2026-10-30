#!/usr/bin/env python3
"""Verify the supported manifest/config relationship without equating their IDs."""

import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tarfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / ".github/scripts"))
from image_identity import (local_identity, registry_identity, scan_identity,
                            validate_local_image, verified_subject)
import build_image


class IdentityTests(unittest.TestCase):
    def test_classic_local_inspect_uses_id_for_docker_and_config_identity(self):
        config = "sha256:" + "1" * 64
        self.assertEqual(local_identity({"Id": config}),
                         dict(mode="local", docker_id=config, config_digest=config))

    def test_containerd_local_identity_hashes_manifest_and_ignores_annotations(self):
        config = "sha256:" + "2" * 64
        raw = json.dumps({"schemaVersion": 2,
                          "mediaType": "application/vnd.oci.image.manifest.v1+json",
                          "config": {"digest": config}, "layers": []}).encode()
        docker_id = "sha256:" + hashlib.sha256(raw).hexdigest()
        image = {"Id": docker_id, "Descriptor": {
            "mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": docker_id}}
        self.assertEqual(local_identity(image, raw),
                         dict(mode="local", docker_id=docker_id, config_digest=config))
        wrong_annotation = image | {"Descriptor": image["Descriptor"] | {
            "annotations": {"config.digest": "sha256:" + "9" * 64}}}
        self.assertEqual(local_identity(wrong_annotation, raw)["config_digest"], config)
        for annotations in ({"config.digest": "bad"}, [], None):
            self.assertEqual(local_identity(image | {"Descriptor": image["Descriptor"] | {
                "annotations": annotations}}, raw)["config_digest"], config)

    def test_saved_manifest_extracts_exact_digest_member_and_drains_archive(self):
        raw = json.dumps({"schemaVersion": 2,
                          "mediaType": "application/vnd.oci.image.manifest.v1+json",
                          "config": {"digest": "sha256:" + "2" * 64}, "layers": []}).encode()
        docker_id = "sha256:" + hashlib.sha256(raw).hexdigest()
        archive = self._archive([(f"blobs/sha256/{docker_id[7:]}", raw), ("extra", b"x")])
        process = self._process(archive)
        with patch.object(build_image.subprocess, "Popen", return_value=process) as popen:
            self.assertEqual(build_image.saved_manifest(docker_id), raw)
        popen.assert_called_once_with(["docker", "image", "save", docker_id], stdout=subprocess.PIPE)
        self.assertEqual(process.stdout.bytes_read, len(archive))
        self.assertTrue(process.wait_called)

    def test_saved_manifest_drains_large_trailing_output_and_checks_real_producer_exit(self):
        raw = json.dumps({"schemaVersion": 2,
                          "mediaType": "application/vnd.oci.image.manifest.v1+json",
                          "config": {"digest": "sha256:" + "2" * 64}, "layers": []}).encode()
        docker_id = "sha256:" + hashlib.sha256(raw).hexdigest()
        archive = self._archive([(f"blobs/sha256/{docker_id[7:]}", raw)])
        with tempfile.NamedTemporaryFile() as fixture:
            fixture.write(archive)
            fixture.flush()
            real_popen = subprocess.Popen
            script = ("import pathlib,sys; sys.stdout.buffer.write(pathlib.Path(sys.argv[1]).read_bytes()); "
                      "sys.stdout.buffer.write(b'x' * 8388608); sys.exit(int(sys.argv[2]))")

            def producer(args, *, stdout):
                self.assertEqual(args, ["docker", "image", "save", docker_id])
                return real_popen([sys.executable, "-c", script, fixture.name, "0"], stdout=stdout)

            with patch.object(build_image.subprocess, "Popen", side_effect=producer):
                self.assertEqual(build_image.saved_manifest(docker_id), raw)

            def failed_producer(args, *, stdout):
                self.assertEqual(args, ["docker", "image", "save", docker_id])
                return real_popen([sys.executable, "-c", script, fixture.name, "9"], stdout=stdout)

            with patch.object(build_image.subprocess, "Popen", side_effect=failed_producer):
                with self.assertRaises(ValueError):
                    build_image.saved_manifest(docker_id)

    def test_saved_manifest_rejects_missing_duplicate_oversized_truncated_and_failed_stream(self):
        raw = b"{}"
        docker_id = "sha256:" + hashlib.sha256(raw).hexdigest()
        member = f"blobs/sha256/{docker_id[7:]}"
        oversized = b"x" * (4 * 1024 * 1024 + 1)
        oversized_id = "sha256:" + hashlib.sha256(oversized).hexdigest()
        truncated = b"x" * 2048
        truncated_id = "sha256:" + hashlib.sha256(truncated).hexdigest()
        nonregular = io.BytesIO()
        with tarfile.open(fileobj=nonregular, mode="w") as archive:
            target = tarfile.TarInfo(member)
            target.type = tarfile.SYMTYPE
            target.linkname = "manifest.json"
            archive.addfile(target)
        malformed = [(self._archive([("other", raw)]), docker_id),
                     (self._archive([(member, raw), (member, raw)]), docker_id),
                     (nonregular.getvalue(), docker_id),
                     (self._archive([(f"blobs/sha256/{oversized_id[7:]}", oversized)]), oversized_id),
                     (self._archive([(f"blobs/sha256/{truncated_id[7:]}", truncated)])[:513], truncated_id)]
        for archive, requested_id in malformed:
            with self.subTest(size=len(archive)):
                process = self._process(archive)
                with patch.object(build_image.subprocess, "Popen", return_value=process):
                    with self.assertRaises((ValueError, OSError, tarfile.TarError)):
                        build_image.saved_manifest(requested_id)
                self.assertTrue(process.wait_called)
        process = self._process(self._archive([(member, raw)]), returncode=9)
        with patch.object(build_image.subprocess, "Popen", return_value=process):
            with self.assertRaises(ValueError):
                build_image.saved_manifest(docker_id)
        self.assertTrue(process.wait_called)

    @staticmethod
    def _archive(entries):
        output = io.BytesIO()
        with tarfile.open(fileobj=output, mode="w") as archive:
            for name, data in entries:
                member = tarfile.TarInfo(name)
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
        return output.getvalue()

    @staticmethod
    def _process(data, returncode=0):
        class Process:
            def __init__(self):
                class Stream(io.BytesIO):
                    def __init__(self, content):
                        super().__init__(content)
                        self.bytes_read = 0

                    def read(self, size=-1):
                        output = super().read(size)
                        self.bytes_read += len(output)
                        return output

                    def readinto(self, buffer):
                        count = super().readinto(buffer)
                        self.bytes_read += count
                        return count
                self.stdout = Stream(data)
                self.returncode = returncode
                self.wait_called = False

            def wait(self, **_kwargs):
                self.wait_called = True
                return self.returncode

            def poll(self):
                return self.returncode

            def terminate(self):
                self.returncode = -15

            def kill(self):
                self.returncode = -9
        return Process()

    def test_containerd_local_identity_rejects_invalid_manifest_and_descriptor(self):
        docker_id = "sha256:" + "1" * 64
        raw = json.dumps({"schemaVersion": 2,
                          "mediaType": "application/vnd.oci.image.manifest.v1+json",
                          "config": {"digest": "sha256:" + "2" * 64}, "layers": []}).encode()
        valid = {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": docker_id}
        for descriptor in (valid | {"digest": "sha256:" + "3" * 64},
                           valid | {"mediaType": "application/vnd.oci.image.index.v1+json"}, []):
            with self.subTest(descriptor=descriptor):
                with self.assertRaises(ValueError):
                    local_identity({"Id": docker_id, "Descriptor": descriptor}, raw)
        with self.assertRaises(ValueError):
            local_identity({"Id": docker_id, "Descriptor": valid}, raw)
        with self.assertRaises(ValueError):
            local_identity({"Id": "sha256:" + hashlib.sha256(raw).hexdigest(),
                            "Descriptor": valid})
        index = json.dumps({"schemaVersion": 2,
                            "mediaType": "application/vnd.oci.image.index.v1+json",
                            "manifests": []}).encode()
        index_digest = "sha256:" + hashlib.sha256(index).hexdigest()
        with self.assertRaises(ValueError):
            local_identity({"Id": index_digest, "Descriptor": {
                "mediaType": "application/vnd.oci.image.index.v1+json", "digest": index_digest}}, index)
        malformed = json.dumps({"schemaVersion": 2,
                                "mediaType": "application/vnd.oci.image.manifest.v1+json",
                                "config": {"digest": "invalid"}, "layers": []}).encode()
        malformed_id = "sha256:" + hashlib.sha256(malformed).hexdigest()
        with self.assertRaises(ValueError):
            local_identity({"Id": malformed_id, "Descriptor": {
                "mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": malformed_id}}, malformed)
        for image in ({}, {"Id": "bad"}, {"Id": docker_id, "Descriptor": "bad"}):
            with self.subTest(image=image):
                with self.assertRaises(ValueError):
                    local_identity(image, raw)

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
