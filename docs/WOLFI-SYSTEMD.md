# Opt-in Wolfi systemd image

`wolfi-systemd` is a separate image flavor for workloads that use normal Linux
user services such as `brew services`. The existing `wolfi` image remains the
non-systemd default.

The new image runs real systemd as container PID 1. Its startup units reuse the
Room of Requirement entrypoint for persistent-home seeding, rootless Podman
preparation, KVM group preparation, and Docker startup. logind owns
`/run/user/1000`; the `vscode` user manager is started with lingering enabled.
The systemd configuration keeps IDE sessions and Homebrew commands under
`vscode` even though container startup runs as root.

Build the opt-in flavor with:

```bash
devcontainer build --workspace-folder . \
  --config src/wolfi-systemd/.devcontainer/devcontainer.json
```

For a Dev Container provider that consumes the published image directly, select
`ghcr.io/joshyorko/room-of-requirement:wolfi-systemd` and preserve these
settings:

```json
{
  "image": "ghcr.io/joshyorko/room-of-requirement:wolfi-systemd",
  "containerUser": "root",
  "remoteUser": "vscode",
  "updateRemoteUserUID": false,
  "overrideCommand": false,
  "privileged": true,
  "runArgs": ["--privileged", "--cgroupns=private"],
  "remoteEnv": {
    "XDG_RUNTIME_DIR": "/run/user/1000",
    "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus"
  }
}
```

The provider must support a private cgroup namespace with delegated cgroup v2
service hierarchy. The included config uses the provider's existing privileged
container contract. Do not add a host cgroup bind, `--cgroupns=host`, or a host
Docker socket. If the provider cannot supply these container-local requirements,
use the existing `wolfi` image.

The image does not install or start T3. Once the unchanged Homebrew formula is
installed by the operator, services run as `vscode` through `brew services` and
`systemctl --user`. No account authorization is performed by the image.

A formula installed into the writable container layer is not retained by a
fresh container recreation. Reinstall runtime-installed formulas after
recreation; the disposable CI smoke does this explicitly and verifies that the
service uses its temporary `T3CODE_HOME`. The smoke separately checks that a
user unit stored in the persistent `vscode` home resumes after recreation.

## Rollback

Select `ghcr.io/joshyorko/room-of-requirement:wolfi`, remove the explicit
`containerUser: "root"` setting, and remove the two systemd entries from
`remoteEnv`. Keep `remoteUser: "vscode"` and the existing Dev Container
startup configuration. The `wolfi` image retains its original entrypoint and
`sleep infinity` command.
