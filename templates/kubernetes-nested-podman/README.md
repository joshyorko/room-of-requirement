# Nested rootless Podman/runsc in a Kubernetes Room

This opt-in **Wolfi/secure** launch prepares a new container's private cgroup
hierarchy for rootless Podman, including runsc. It does not install or select
runsc. Supply the complete, verified runtime bundle separately.

Use an image containing `ror-nested-podman-bootstrap.sh` and the matching Room
entrypoint. Adding this template to an older published image is insufficient.
The existing default Docker-in-Docker launch is unchanged. In this opt-in mode,
the entrypoint prepares Podman and **does not start Docker-in-Docker**.

## Launch contract

- Devsy 1.17.0 or a version with equivalent Pod template security-context merges.
- Linux cgroup v2; outer runtime must give nonprivileged containers a private
  cgroup namespace rooted at their own container cgroup. Verified with
  containerd 2.3.2-k3s2 on K3s 1.36.3+k3s1 / Rocky Linux 9.8.
- Root startup, `privileged: false`, added `SYS_ADMIN`, and the usual OCI
  capabilities including `CHOWN`, `MKNOD`, `SETUID` and `SETGID`. Interactive
  commands and Podman run as `vscode`, with the image's subordinate UID/GID maps.
- `hostUsers: true`; `STRICT_SECURITY=false`. This is not the Devsy experimental
  outer user-namespace mode. The Pod template overrides the image's privileged
  setting explicitly; it does not rely on an empty/omitted boolean.
- Outer controllers include `cpu cpuset io memory pids`; all controllers visible
  in the container are enabled for descendants. CPU/memory/pids limits imposed
  by Kubernetes remain owned by the outer runtime.
- The outer device policy permits TUN character device `10:200`. The bootstrap
  creates its node only in the new container's `/dev`; it does not change device
  policy or mount a host device directory. Preserve the image PATH for pasta.

`SYS_ADMIN` is a substantial capability. This profile does not satisfy Kubernetes
Restricted Pod Security. It does not add blanket privilege, host networking,
host paths, service-account tokens, or a host-runtime socket.

The template inherits cluster SELinux and seccomp policy without changing it.
The tested node used SELinux process type `unconfined_service_t` and inherited
seccomp mode 0. This is not proof of `container_t` confinement. An additional
test with explicit `RuntimeDefault` seccomp failed at pasta's `pivot_root` with
`EPERM`; do not advertise that profile as supported. A cluster that requires it
needs a separately reviewed, runtime-compatible seccomp profile. Do not disable
cluster policy to make this recipe pass.

## New Devsy workspace only

Run from the **Linux controller** in this repository, after an approved image
containing this change is available to the Kubernetes nodes. Set
`ROR_NESTED_IMAGE` to that image's immutable registry reference. The command uses
a new workspace ID and the per-workspace template option; do not apply it to an
existing Room or reuse its volumes.

```sh
: "${ROR_NESTED_IMAGE:?Set the approved image reference containing this change}"
devsy workspace up . \
  --id room-nested-podman-new \
  --provider kubernetes \
  --devcontainer src/wolfi/.devcontainer/devcontainer.json \
  --devcontainer-image "$ROR_NESTED_IMAGE" \
  --provider-option "POD_MANIFEST_TEMPLATE=$PWD/templates/kubernetes-nested-podman/pod-template.yaml" \
  --provider-option STRICT_SECURITY=false \
  --ide-launch skip
```

Set the provider's context, namespace, placement and resource requests for your
cluster and check capacity before creating the workspace. Do not reuse an
existing ID: Devsy may reconcile changed options by recreating its pod.

Devsy 1.17.0 merges the template's `devsy` container security context after
generating its defaults. The template therefore overrides `privileged: true`
from the Wolfi devcontainer, retains root startup and supplies the opt-in env.
`hostUsers: true` prevents an unrelated provider option from implicitly selecting
outer user namespaces. No node runtime configuration or restart is required on
the verified K3s/containerd stack.

## Acceptance and rollback

Inside the **new Kubernetes workspace**, as `vscode`, run:

```sh
ujust podman-runsc-check /absolute/path/to/complete-pinned-bundle/runsc
```

Require its final PASS, including rootless Podman identity, the running
container's absolute runsc identity, synthetic execution, ordinary pasta/HTTPS
networking, and empty isolated container/image inventories after cleanup.
Controller visibility or the bootstrap's startup message alone is insufficient.
Neither a bare VM pass nor an outer gVisor RuntimeClass establishes this result.

The bootstrap is deliberately startup-only. It rejects a host-visible cgroup
path, the global hierarchy root, non-root startup, missing controllers and a
previously initialized container. It moves only the new container's initial
processes into `room-init` and delegates only its namespace-root directory,
`cgroup.procs`, `cgroup.threads` and `cgroup.subtree_control` to the actual vscode
UID/GID. It never recursively changes ownership or writes outer resource limits.

Rollback for a disposable test is to remove only that test pod and its owned
ConfigMap after retaining logs; Kubernetes removes its cgroup and writable layer.
For a persistent workspace, preserve its data and retire the opt-in workspace
through your normal reviewed lifecycle. Remove the template option for future
launches. Do not attempt to undo delegation in a running workspace or delete
its volumes as part of this change.

## Upstream mechanisms

- [containerd 2.3.2 private cgroup namespace selection](https://github.com/containerd/containerd/blob/v2.3.2/internal/cri/server/container_create.go#L806)
- [Kernel cgroup namespace mounting and delegation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html#namespace)
- [runsc release-20260831.0 cgroup-root traversal](https://github.com/google/gvisor/blob/release-20260831.0/runsc/cgroup/cgroup_v2.go#L105)
- [Devsy 1.17.0 template security-context precedence](https://github.com/devsy-org/devsy/blob/v1.17.0/pkg/driver/kubernetes/init_container.go#L115)

The feature-aware Wolfi image build and disposable Kubernetes startup test are
separate gates. Testing byte-identical bootstrap files via a test ConfigMap does
not mean a published image or an existing workspace has been updated.
