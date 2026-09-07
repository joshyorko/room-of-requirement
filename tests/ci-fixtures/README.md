# CI scan fixture

`grype-image.json` is the unmodified Grype JSON presenter image snapshot from
`anchore/grype` commit `65ec52e70a3738aed415858188e403eba7e61ccf`, path
`grype/presenter/json/testdata/snapshot/TestJsonImgsPresenter.golden` (Apache-2.0).
The test derives critical, unfixed, duplicate, empty, and malformed cases in memory.
Its second match has an explicitly empty fix state and empty versions list.
This producer zero value means unknown/no known fix, including for Critical
findings; missing fields and contradictory state/version pairs remain invalid.
Counts are unique vulnerability IDs per severity; the gate counts only critical
IDs with a fixed version after the repository's Grype ignore policy is applied.

`grype-zero-fix.json` projects the parser-consumed vulnerability/artifact fields
from actual Grype 0.118.0 reports produced on 2026-09-06:
`/tmp/ror-remediation-validation/final-ubuntu-noble/grype.json` (GO-2026-4887)
and `/tmp/ror-remediation-validation/final-wolfi/grype.json` (GO-2026-5932).
The tests retain their High/Unknown severities and zero-value fix objects,
combining them with the existing image-identity fixture.

`cosign-v3-bundle.json` is the unmodified public fixture
`pkg/cosign/testdata/oci-attestation.sigstore.json` from `sigstore/cosign` v3.0.5,
commit `479147a4df05f31be48aeb2b3a9d32dfc35ba877` (Apache-2.0).
The mixed-format test derives parseable v3 SPDX/context bundles and a legacy SLSA
layer in memory. Their modified payloads intentionally invalidate signatures:
the test proves real Cosign format routing and rejection, not successful signing.
