#!/usr/bin/env python3
"""Probe actual Cosign 3 against a read-only mixed-format registry fixture.

The fixture signatures intentionally cannot satisfy the production SLSA identity.
This tests format routing and fail-closed behavior, not hosted signing acceptance.
"""

import base64
import copy
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / ".github/scripts/verify_provenance.py"
OCI = "application/vnd.oci.image.manifest.v1+json"
INDEX = "application/vnd.oci.image.index.v1+json"


def encoded(value):
    return json.dumps(value).encode()


def hashed(value):
    return "sha256:" + hashlib.sha256(value).hexdigest()


class CosignFormatTests(unittest.TestCase):
    def test_legacy_slsa_is_reached_with_v3_bundles_present_without_relaxing_verification(self):
        cosign = shutil.which("cosign")
        self.assertIsNotNone(cosign, "Install the pipeline's Cosign 3.0.5 to run this required probe")
        version = subprocess.run([cosign, "version"], text=True, capture_output=True, check=True)
        self.assertIn("v3.0.5", version.stdout + version.stderr)
        routes, requests = {}, []

        def blob(data, media):
            digest = hashed(data)
            routes["/v2/ci/fixture/blobs/" + digest] = (data, media)
            return dict(mediaType=media, digest=digest, size=len(data))

        config = blob(b'{}', "application/vnd.oci.image.config.v1+json")

        def manifest(layers):
            raw = encoded(dict(schemaVersion=2, mediaType=OCI, config=config, layers=layers))
            digest = hashed(raw)
            routes["/v2/ci/fixture/manifests/" + digest] = (raw, OCI)
            return raw, dict(mediaType=OCI, digest=digest, size=len(raw))

        _, subject = manifest([])
        bundle = json.loads((ROOT / "tests/ci-fixtures/cosign-v3-bundle.json").read_text())
        bundles = []
        for predicate in ("https://spdx.dev/Document", "https://example.invalid/build-context/v1"):
            derived = copy.deepcopy(bundle)
            statement = json.loads(base64.b64decode(derived["dsseEnvelope"]["payload"]))
            statement["predicateType"] = predicate
            derived["dsseEnvelope"]["payload"] = base64.b64encode(encoded(statement)).decode()
            _, descriptor = manifest([blob(encoded(derived), "application/vnd.dev.sigstore.bundle.v0.3+json")])
            bundles.append(descriptor)
        routes["/v2/ci/fixture/referrers/" + subject["digest"]] = (
            encoded(dict(schemaVersion=2, mediaType=INDEX, manifests=bundles)), INDEX)
        legacy = copy.deepcopy(bundle["dsseEnvelope"])
        statement = json.loads(base64.b64decode(legacy["payload"]))
        statement["predicateType"] = "https://slsa.dev/provenance/v0.2"
        legacy["payload"] = base64.b64encode(encoded(statement)).decode()
        legacy_layer = blob(encoded(legacy), "application/vnd.dsse.envelope.v1+json")
        legacy_layer["annotations"] = {"dev.cosignproject.cosign/signature": ""}
        legacy_raw, _ = manifest([legacy_layer])
        legacy_path = "/v2/ci/fixture/manifests/" + subject["digest"].replace(":", "-") + ".att"
        routes[legacy_path] = (legacy_raw, OCI)

        class Registry(BaseHTTPRequestHandler):
            def do_GET(self):
                self.respond(False)

            def do_HEAD(self):
                self.respond(True)

            def respond(self, head):
                path = self.path.split("?", 1)[0]
                requests.append(path)
                value = (b'{}', "application/json") if path == "/v2/" else routes.get(path)
                if value is None:
                    self.send_error(404)
                    return
                data, media = value
                self.send_response(200)
                self.send_header("Content-Type", media)
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Docker-Content-Digest", hashed(data))
                self.end_headers()
                if not head:
                    self.wfile.write(data)

            def log_message(self, *args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Registry)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with tempfile.TemporaryDirectory() as temp:
                output = Path(temp) / "output"
                env = dict(os.environ, IMAGE=f"127.0.0.1:{server.server_port}/ci/fixture",
                           DIGEST=subject["digest"], GENERATOR_RESULT="success", GITHUB_OUTPUT=str(output))
                # Control: pinned Cosign's default sees the existing v3 bundles and
                # never attempts the legacy provenance, even though its tag exists.
                control = subprocess.run([
                    cosign, "verify-attestation", "--check-claims", "--type", "slsaprovenance",
                    "--certificate-identity",
                    "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/v2.1.0",
                    "--certificate-oidc-issuer", "https://token.actions.githubusercontent.com",
                    env["IMAGE"] + "@" + env["DIGEST"],
                ], capture_output=True, text=True, timeout=60, check=False)
                self.assertNotEqual(control.returncode, 0)
                self.assertIn("/v2/ci/fixture/referrers/" + subject["digest"], requests)
                self.assertNotIn(legacy_path, requests)
                requests.clear()
                result = subprocess.run(["python3", str(SCRIPT)], env=env, capture_output=True,
                                        text=True, timeout=60, check=False)
                self.assertNotEqual(result.returncode, 0, "Untrusted fixture must never authorize a subject")
                self.assertFalse(output.exists())
                self.assertIn(legacy_path, requests, result.stderr[-2000:])
                self.assertIn("/v2/ci/fixture/blobs/" + legacy_layer["digest"], requests)
                self.assertNotIn("/v2/ci/fixture/referrers/" + subject["digest"], requests)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    unittest.main()
