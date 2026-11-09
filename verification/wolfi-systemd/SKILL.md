---
name: verify-wolfi-systemd
description: Verify RoR Wolfi systemd boot ordering, user services, restart/recreation, and disposable cleanup after changes to the covered runtime or smoke scripts.
---

# Verify Wolfi systemd lifecycle

The property is that user workloads cannot be admitted before successful HOME initialization and the UID 1000 logind/user-manager prerequisites. A false success can expose an unusable persistent home to services.

Read the installed `pstack:statechart` skill before checking this TLA+ model. Copy this directory's model, configuration, and view files into a fresh scratch directory outside the repository, and use that skill's current runner. Read every result through `/statechart`; do not infer real container readiness from a model pass.

Coverage: `src/common/entrypoint.sh` home-seeder result handling; `src/wolfi/systemd/*.service` ordering, lingering and Docker ownership; `src/wolfi/.devcontainer/Dockerfile` final targets; `src/wolfi-systemd/.devcontainer/devcontainer.json` UID/private-cgroup contract; `.github/scripts/wolfi-systemd-runtime-smoke.sh` lifecycle and cleanup. The model abstracts systemd/API commands as atomic outcomes. Package names, CI fixture selection and supply-chain gates require their existing executable regression tests.

Source synchronization baseline: `e5b6ef909b843f9cf361062b4393844337db8a6e`. Confirm the mapping against the covered source before moving this baseline to a later commit.

Use `SystemdGood.cfg`, `SystemdSeedRejected.cfg`, `LegacyWolfi.cfg`, `MissingCgroup.cfg`, `DockerUnavailable.cfg`, `VolumeCollision.cfg`, and `KvmAvailable.cfg` as passing scenarios. `MissingPackages.cfg` must violate `StartupSettles`: PID 1 and D-Bus can run while a missing `systemd-logind-service` prevents initialization and user-manager readiness. Hosted run 42629208843/job 129201432555 replayed this path; the Dockerfile now installs that split package and checks its service/binary plus both user-manager template units at build time.

`SystemdSeedIgnored.cfg` reproduces the old warning-and-continue defect and must violate `InitCompleteRequiresSeed`, `ManagerRequiresBootstrap`, and `BrewServiceContract`. `PodmanPrepFailure.cfg` and `KvmPrepFailure.cfg` must violate `RuntimeSmokePasses`. `CgroupHost.cfg` and `UidRemapped.cfg` must reject their configuration invariants. An unexpected result is a verification failure, not permission to weaken a rule.

Run `bash tests/wolfi-systemd-init-test.sh` to replay the seeder counterexample against actual shell control flow. It redirects only the external seeder in a scratch copy and fakes host-mutating commands. The test must reject failed systemd initialization while preserving legacy warning-and-continue behavior.

Bounds: one container at a time, at most two fresh recreations, one Docker daemon and one T3 process/listener per running generation. Weak fairness applies to startup and smoke-gate actions; explicit container stop cancels startup. HOME and its probe unit persist across recreation; runtime-installed Homebrew formulas and temporary T3 state do not. Reinstalling the formula is an explicit disposable-test action, never image startup behavior.

Model checks do not establish actual PID 1, cgroup delegation, PAM/D-Bus behavior, Homebrew service readiness, Devsy SSH/IDE behavior, or KVM availability. Run `.github/scripts/runtime-smoke.sh IMAGE wolfi-systemd` only with an identified disposable candidate/runtime. Record image identity and each unavailable gate as NOT VERIFIED or NOT RUN. Use `/maintain-formal-verification-skill` after covered source changes that were not rechecked.

The model's Brew activation abstracts completed application readiness, not just an active systemd unit. Real startup is asynchronous: the smoke must wait up to 30 seconds for a TCP listener owned by the original service PID. `python3 tests/ci-execution-test.py HomebrewListenerTests` executes the actual probe against deterministic procfs/clock fixtures for delayed readiness, absent/foreign listeners and process exit. These fixtures cannot prove the real application's readiness; only disposable runtime execution can.
