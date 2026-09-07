# Audit remediation implementation plan

Spec: docs/superpowers/specs/2026-09-06-audit-remediation-design.md
Source evidence: /tmp/ror-astra-audit-27d68b0-20260906/review.md and scoped reports in that directory.

## Global constraints

Two implementation writers at most, each in a disjoint worktree and file scope. Parent owns integration, plan ledger, documentation reconciliation and acceptance. Preserve existing data and strict gates. Workers must add meaningful regression tests before behavioral fixes, run their focused checks, commit coherent changes, report exact SHAs and limitations, and never push or alter live runtimes. Existing audit probes establish failures but tests must exercise maintained source behavior. Use normal Sol/Terra for bounded implementation; Astra for publication architecture and final review. Do not spawn descendants.

## Task 1: Runtime, image and project initialization

Owner: runtime worker. Files: src/**; .devcontainer/devcontainer.json; templates/ror-starter/**; tests/runtime-* and the three existing shell contract tests; docs/DEVPOD-HOME-PERSISTENCE.md. No .github or automation edits. Add scripts/config dependencies required by runtime to every variant Dockerfile.

1. Add regression coverage for mapped/special metadata preservation, missing Podman defaults, isolated graph volume names, compact/pretty daemon JSON, data-root/config forwarding, exited daemon/stale socket/timeout, required hydration failures and Brewfile handling, apk argument forwarding/failure propagation.
2. Repair ownership/initialization and volume scoping with explicit migration instructions. Keep login-UID migration conservative and preserve old stores. Remove only the misplaced brew-cache mount declaration, not stored data.
3. Repair effective Docker configuration/driver selection/readiness and isolate tests from host daemon configuration. Use a JSON parser guaranteed by the images.
4. Make project hydration deterministic and failure-aware, support project mise configuration and Brewfile conventions, remove unconditional package updates/global runtime installs/cache purge, provide explicit default-runtime setup. Retarget template and remove competing lifecycle fallbacks.
5. Fix apk wrapper/update RUN, remove broken healthchecks, install Homebrew as final owner without a later copy-up layer. Preserve native-gem/browser functionality. Do not delete legacy copies; Task 4 owns retirement.
6. Run focused tests/syntax checks, self-review and commit.

## Task 2: Verified image publication and releases

Owner: CI worker. Files: .github/workflows/build-image.yml, build-devcontainers.yml, build-templates.yml, release.yml; new .github/scripts/**; tests/ci-*; .github/workflows/codeql.yml only if necessary. No runtime, automation, or Renovate edits.

1. Add regression fixtures for scan schema, missing/true/false input policy, scanner errors/missing output, permitted source/ref/freshness and final promotion gates. Prefer testable small scripts over complex inline shell.
2. Establish one reusable feature-aware image build/check pipeline. PRs build and test images without push. Retain all variants and existing Docker/Podman runtime contracts. Retain signing/SBOM/scanning/provenance on the exact candidate digest; public aliases move only after all gates succeed.
3. Use shared promotion concurrency and ref/source freshness checks; branch candidates never receive production aliases. Keep alias promotion short; expose immutable digest. Do not rebuild after checks.
4. Normalize critical enforcement defaults and reject scanner execution/missing-report failures. Parse actual Grype JSON or correct SARIF rule metadata; preserve scan/SBOM artifacts and CodeQL.
5. Add explicit variant-scoped persistent BuildKit cache with deliberate scheduled refresh. Remove dead workflow_run and closed-PR no-op triggers, redundant publisher work and unused misleading inputs. Pin supporting CLI dependencies where practical.
6. Wire successful Release Please output to explicit released-source/version image publication. Validate starter application/build on template changes through appropriate shared pipeline integration. Parent may help fix cross-scope inputs.
7. Run fixture tests, YAML/action validation and self-review; commit. Do not push images or workflows.

## Task 3: Maintenance contracts and canonical dependency ownership

Queued until a writer slot is free. Files: automation/maintenance-robot/**; .github/renovate.json5; .github/workflows/rcc-maintenance.yml; published devcontainer-lock.json files only (not devcontainer.json).

1. Add real YAML and temporary-file regression tests for pinned Actions/comment handling, semver/release ordering, prerelease policy, atomic tag/digest changes, unknown tap member metadata, canonical Brewfiles and published feature configs.
2. Fix retained updater APIs without weakening no-downgrade policy; only update validated matching version/checksum pairs atomically and report digest-only changes. Select greatest allowed stable version independent of API order.
3. Let Renovate own standard Actions/Dockerfile/pre-commit maintenance. Remove overlapping operations from the automatic robot path, stale informational daily lookups and obsolete hadolintw tracking. Keep useful manual compatibility paths correct or explicitly retire them with docs.
4. Validate src/common/brew with an unknown-membership fallback; enumerate every supported feature config for lockfile refresh, and correct specialized published targets. Add a non-mutating contained unit-test task; use it before final report. Do not run full maintenance against source.
5. Update robot docs, source-specific checks and locks, run focused/contained tests, self-review and commit.

## Task 4: Integrate, retire duplicates, document and accept

Parent owns integration after task reviews, README.md, AGENTS.md, docker-bake.hcl, legacy .devcontainer payload retirement, repository lint configuration and final acceptance docs. Parent edits source only with a free writer slot or by assigning fixes back to its owner.

1. Review each task against spec and focused evidence; integrate exact coherent commits. Feed findings back to the same owner with bounded fix/review rounds.
2. Migrate remaining legacy references and remove unused .devcontainer Dockerfile/brew/config/scripts/bootstrap payloads while preserving its active config/lock. Update contributor guidance and README to actual behavior. Make raw Bake debug tags unambiguously non-production. Correct build-context ignore placement.
3. Run all relevant unit/contract checks, contained robot tests, pre-commit/actionlint, feature-aware builds and disposable runtime smoke tests. Validate failed checks cannot promote aliases. Check existing/mounted home and two distinct storage identities. Measure image layer changes without promising a fixed byte saving from changed upstream dependency versions.
4. Obtain independent Astra whole-branch review, fix actionable findings and re-review. Keep a completion ledger mapping every audit concern to code/test/evidence or explicit retained qualified behavior.
5. Commit final integrated work on patchraptor/audit-remediation. Prepare a concrete reviewable result; do not merge, deploy, mutate production tags, or migrate live volumes.
