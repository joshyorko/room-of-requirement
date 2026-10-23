# Build toolchain repair

Goal: repair the failed Cosign probe and satisfy issue #514 without publishing images or templates.

Constraints: retain Action SHAs, source/digest/destination checks, and release gates. Node 24 must be at least 24.22.1. CI Node does not prove runtime remediation.

- [x] Inspect run 40009324942 and map image/template build paths.
- [x] Make the Cosign fixture use the workflow's installed version, retaining its real fail-closed registry probe.
- [x] Pin build Node centrally, enforce the security floor, and record exact Node/CLI versions and verified CLI package hashes.
- [x] Inventory Node packages in image SBOMs and record template package/source/applied-payload hashes. Pin the starter's declared Node runtime and check it after hydration.
- [ ] Run regression tests and lint with the patched toolchain. Qualify images and templates without publication; preserve evidence and report any blocked gates.

Tests must reject stale/prerelease Node and modified package bytes. Inventory tests must distinguish absent Node from a missing or malformed SBOM. Existing identity and publication-denial tests must continue to pass.
