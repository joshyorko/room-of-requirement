# Audit remediation design

The user approved implementation of the integrated 2026-09-06 Astra audit after reviewing its findings and proposed fix directions. This design records that existing approval; it does not reopen planning.

## Contracts

- Preserve existing user content, subordinate UID/GID ownership, special permission bits, and persistent volume data. Initialize only new objects; never recursively normalize existing storage. New daemon stores are workspace-scoped. Existing volumes require an explicit documented migration, never automatic deletion or destructive copy.
- Resolve Docker configuration/data-root consistently for inspection and launch. Parse JSON properly, honor configuration precedence, detect daemon exit, use API readiness, and return failures accurately. Seed missing Podman configuration outside mounted image-home paths without overwriting user settings.
- Project hydration installs declared dependencies and propagates required failures. Global language defaults and upgrades become explicit opt-in commands; npm cache is retained. Templates use the supported current image and one deterministic hydration owner.
- One CI pipeline builds each requested variant once, runs real image/runtime checks on PRs, publishes only immutable candidates, completes runtime/security/signature/SBOM/provenance checks on that digest, then promotes aliases. Promotion is serialized and restricted to approved main/release sources with freshness checks. Missing scanner output/errors fail; absent policy inputs enforce critical-with-fixes policy. Releases explicitly invoke publication with release version/source.
- Shared persistent BuildKit cache is variant-scoped; scheduled refresh must still refresh intended mutable dependencies. Keep CodeQL and all security artifacts. Eliminate dead feature triggers and duplicate monthly publisher work.
- Renovate owns standard Actions, Dockerfile and pre-commit dependency updates. RCC retains specialized validation, dependency updates not delegated, and all published feature-lock refresh. Retained updater APIs remain correct: YAML comments, semver/prerelease ordering, atomic version/digest pairs, canonical paths, and unknown tap membership handling.
- src/common and src/<variant> are canonical. Retire the legacy payload only after migrating helpers/allowlists/guidance. Keep the live .devcontainer entry config. Fix apk wrapper and package failure propagation, omit meaningless healthchecks, and eliminate Homebrew ownership copy-up without breaking final ownership.
- Retain working browser, compiler/native-gem and variant capabilities unless a demonstrated-safe optional profile replaces them. No blanket package deletion follows from prebuilt Ruby. Quantify image savings only after comparable builds.

## Scope and acceptance

Implementation covers every confirmed defect in the integrated audit, the earlier validated optimizations, and the documented qualifications. Hypothetical incidents are not acceptance claims. Preserve failure-injection tests and test real parsers where possible. Run repository lint, contained maintenance tests, feature-lock validation, image builds and runtime checks appropriate to the changes. Use disposable test containers/volumes only. No production deployment, live volume migration, merge, or public tag mutation is part of local implementation.
