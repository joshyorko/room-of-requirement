export const title = "Room of Requirement Wolfi systemd lifecycle";

export const state = (v) => {
  const s = v.s;
  if (s.container === "failed") return "Container startup rejected";
  if (s.container === "absent" && s.volumeDeleted) return "Owned test resources cleaned";
  const smokeFailures = [
    s.podmanSmokeResult === "fail" ? "rootless Podman failed" : null,
    s.kvmSmokeResult === "fail" ? "KVM setup failed" : null,
    s.dockerSmokeResult === "fail" ? "nested Docker failed" : null,
  ].filter(Boolean);
  const suffix = smokeFailures.length ? `; ${smokeFailures.join(", ")}` : "";
  if (s.brewActive && s.runtimeSmokeStarted) return `T3 service active as runtime smoke starts${suffix}`;
  if (s.brewActive && s.shellDetachedWithBrew && !s.homeSeeded)
    return `T3 service remains after shell detach with HOME unseeded${suffix}`;
  if (s.brewActive && s.shellDetachedWithBrew) return `T3 service active after shell detach${suffix}`;
  if (s.brewActive && !s.homeSeeded) return `T3 service active while HOME is unseeded${suffix}`;
  if (s.brewActive) return `Homebrew T3 service active as vscode${suffix}`;
  if (s.brewUnitRegistered) return `Homebrew unit registered, inactive${suffix}`;
  if (s.runtimeSmokeStarted && s.kvmSmokeChecked && s.podmanSmokeResult === "pass" && s.dockerSmokeResult === "pass")
    return `Runtime smoke complete; KVM ${s.kvmSmokeResult}${suffix}`;
  if (s.runtimeSmokeStarted && s.podmanSmokeChecked) return `Podman smoke ${s.podmanSmokeResult}${suffix}`;
  if (s.runtimeSmokeStarted && s.dockerSmokeChecked) return `Docker smoke ${s.dockerSmokeResult}${suffix}`;
  if (s.runtimeSmokeStarted) return `Runtime smoke started${suffix}`;
  if (s.brewLifecycleComplete) return `Homebrew service stopped; container contracts remain${suffix}`;
  if (s.kvmSmokeChecked && s.podmanSmokeResult === "pass" && s.dockerSmokeResult === "pass")
    return `Docker and Podman passed; KVM ${s.kvmSmokeResult}${suffix}`;
  if (s.podmanSmokeChecked) return `Docker and Podman smoke ${s.podmanSmokeResult}${suffix}`;
  if (s.dockerSmokeChecked) return `Docker smoke ${s.dockerSmokeResult}${suffix}`;
  if (s.formulaInstalled) return `T3 formula installed; user service not started${suffix}`;
  if (s.userManager && !s.homeSeeded) return "vscode user manager ready with HOME unseeded";
  if (s.userManager) return "vscode user manager ready";
  if (s.dockerReady && !s.homeSeeded) return "Docker ready with HOME unseeded";
  if (s.dockerReady) return "RoR initialization and Docker ready";
  if (s.initFailed) return "RoR initialization failed closed";
  if (s.initComplete && !s.homeSeeded) return "Init reported success with HOME unseeded";
  if (s.dbusReady && s.logindReady) return "system D-Bus and logind ready";
  if (s.systemdActive) return "systemd is container PID 1";
  if (s.pid1 === "entrypoint") return "legacy Wolfi entrypoint remains PID 1";
  if (s.container === "created") return `Container created (generation ${s.generation})`;
  if (s.container === "stopped") return "Container stopped";
  return "No test container";
};

export const step = (action) => ({
  CreateContainer: "create disposable container and owned volumes",
  RejectVolumeCollision: "reject a pre-existing test volume",
  BootSystemd: "systemd becomes PID 1",
  BootLegacyWolfi: "legacy Wolfi starts its entrypoint",
  BootRejected: "fail startup when required cgroups are unavailable",
  StartDBus: "start system D-Bus",
  StartLogind: "start logind",
  InitializeHomeSuccess: "seed only missing HOME defaults",
  InitializeHomeFailureIgnored: "HOME seeding fails but init reports success",
  InitializeHomeFailureRejected: "fail the systemd init unit on HOME seeding failure",
  StartDocker: "Docker API becomes ready",
  DockerStartRejected: "Docker readiness fails",
  EnableLinger: "logind enables vscode lingering",
  StartUserManager: "start user@1000 and its runtime directory",
  RegisterProbeUnit: "register the disposable user unit in HOME",
  StartProbeUnit: "start the probe user unit as vscode",
  CheckPodmanSmoke: "check rootless Podman setup",
  CheckKvmSmoke: "check KVM when present or report NOT RUN",
  CheckDockerSmoke: "check nested Docker",
  InstallFormula: "install the unchanged Homebrew formula explicitly",
  StartBrewService: "start one t3 serve Homebrew service",
  RestartBrewService: "restart the Homebrew service",
  DetachShell: "detach the shell while the service remains active",
  AttachShell: "attach a vscode shell",
  StopBrewService: "stop and unregister the test Homebrew service",
  BeginRuntimeSmoke: "begin Docker, Podman, and KVM runtime checks",
  StopContainer: "stop the container and its systemd-managed processes",
  RestartContainer: "restart the same container and writable layer",
  RecreateContainer: "recreate the container with only HOME persisted",
  PersistedBrewCannotRun: "observe a persisted unit without its container-layer formula",
  RemoveContainer: "remove the owned container",
  PartialCleanupFailure: "container removal fails; keep remaining resources",
  DeleteOwnedTestVolume: "delete only the volume labeled for this run",
}[String(action)] ?? null);

export const group = (v) => {
  const s = v.s;
  if (s.initFailed || s.container === "failed" || s.podmanSmokeResult === "fail" ||
      s.kvmSmokeResult === "fail" || s.dockerSmokeResult === "fail") return "failed";
  if (s.userManager) return "ready";
  if (s.container === "stopped" || (s.container === "absent" && s.volumeDeleted)) return "stopped";
  return "boot";
};

export const colors = { boot: "blue", ready: "teal", stopped: "tan", failed: "pink" };
