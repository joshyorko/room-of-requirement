--------------------------- MODULE WolfiSystemdLifecycle ---------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS Flavor, SeedFailurePolicy, SeedFails,
          CgroupDelegated, PackagesInstalled, DockerAvailable, VolumeAlreadyExists,
          PodmanPrepSucceeds, KvmDevicePresent, KvmPrepSucceeds,
          CgroupNamespace, VscodeUID

VARIABLE s
vars == <<s>>

Init ==
    s = [
        container |-> "absent",
        generation |-> 0,
        pid1 |-> "none",
        systemdActive |-> FALSE,
        dbusReady |-> FALSE,
        logindReady |-> FALSE,
        cgroupNamespace |-> CgroupNamespace,
        vscodeUID |-> VscodeUID,
        runtimeOwner |-> "none",
        homeVolume |-> FALSE,
        homeSeeded |-> FALSE,
        initComplete |-> FALSE,
        initFailed |-> FALSE,
        initAttempts |-> 0,
        linger |-> FALSE,
        userManager |-> FALSE,
        dockerReady |-> FALSE,
        dockerStarts |-> 0,
        podmanStorageReady |-> FALSE,
        podmanSmokeChecked |-> FALSE,
        podmanSmokeResult |-> "pending",
        kvmPrepared |-> FALSE,
        kvmSmokeChecked |-> FALSE,
        kvmSmokeResult |-> "pending",
        dockerSmokeChecked |-> FALSE,
        dockerSmokeResult |-> "pending",
        probeUnitRegistered |-> FALSE,
        probeUnitActive |-> FALSE,
        formulaInstalled |-> FALSE,
        brewUnitRegistered |-> FALSE,
        brewLifecycleComplete |-> FALSE,
        runtimeSmokeStarted |-> FALSE,
        brewUnitFailed |-> FALSE,
        brewActive |-> FALSE,
        brewRestarts |-> 0,
        brewPids |-> 0,
        tcpListeners |-> 0,
        shellAttached |-> FALSE,
        shellDetachedWithBrew |-> FALSE,
        t3Home |-> "absent",
        volumeOwner |-> IF VolumeAlreadyExists THEN "other" ELSE "none",
        volumeDeleted |-> FALSE,
        deletedVolumeOwner |-> "none",
        cleanupError |-> FALSE
    ]

CreateContainer ==
    /\ s.container = "absent"
    /\ ~s.volumeDeleted
    /\ ~VolumeAlreadyExists
    /\ s' = [s EXCEPT !.container = "created",
                    !.homeVolume = TRUE,
                    !.volumeOwner = "this-run",
                    !.volumeDeleted = FALSE,
                    !.deletedVolumeOwner = "none"]

RejectVolumeCollision ==
    /\ s.container = "absent"
    /\ VolumeAlreadyExists
    /\ s' = [s EXCEPT !.container = "failed"]

BootSystemd ==
    /\ Flavor = "wolfi-systemd"
    /\ s.container = "created"
    /\ CgroupDelegated
    /\ CgroupNamespace = "private"
    /\ s' = [s EXCEPT !.container = "running",
                    !.pid1 = "systemd",
                    !.systemdActive = TRUE]

BootLegacyWolfi ==
    /\ Flavor = "wolfi"
    /\ s.container = "created"
    /\ s' = [s EXCEPT !.container = "running",
                    !.pid1 = "entrypoint",
                    !.systemdActive = FALSE]

BootRejected ==
    /\ Flavor = "wolfi-systemd"
    /\ s.container = "created"
    /\ (~CgroupDelegated \/ CgroupNamespace # "private")
    /\ s' = [s EXCEPT !.container = "failed",
                    !.initFailed = TRUE]

StartDBus ==
    /\ s.container = "running"
    /\ s.systemdActive
    /\ ~s.dbusReady
    /\ s' = [s EXCEPT !.dbusReady = TRUE]

StartLogind ==
    /\ s.container = "running"
    /\ s.systemdActive
    /\ PackagesInstalled
    /\ ~s.logindReady
    /\ s' = [s EXCEPT !.logindReady = TRUE]

InitializeHomeSuccess ==
    /\ s.container = "running"
    /\ s.systemdActive
    /\ s.dbusReady
    /\ s.logindReady
    /\ s.initAttempts = 0
    /\ ~SeedFails
    /\ s' = [s EXCEPT !.homeSeeded = TRUE,
                    !.initComplete = TRUE,
                    !.initFailed = FALSE,
                    !.podmanStorageReady = PodmanPrepSucceeds,
                    !.kvmPrepared = KvmDevicePresent /\ KvmPrepSucceeds,
                    !.initAttempts = 1]

InitializeHomeFailureIgnored ==
    /\ s.container = "running"
    /\ s.systemdActive
    /\ s.dbusReady
    /\ s.logindReady
    /\ s.initAttempts = 0
    /\ SeedFails
    /\ SeedFailurePolicy = "warn-and-continue"
    /\ s' = [s EXCEPT !.homeSeeded = FALSE,
                    !.initComplete = TRUE,
                    !.initFailed = FALSE,
                    !.podmanStorageReady = PodmanPrepSucceeds,
                    !.kvmPrepared = KvmDevicePresent /\ KvmPrepSucceeds,
                    !.initAttempts = 1]

InitializeHomeFailureRejected ==
    /\ s.container = "running"
    /\ s.systemdActive
    /\ s.dbusReady
    /\ s.logindReady
    /\ s.initAttempts = 0
    /\ SeedFails
    /\ SeedFailurePolicy = "fail-closed"
    /\ s' = [s EXCEPT !.homeSeeded = FALSE,
                    !.initComplete = FALSE,
                    !.initFailed = TRUE,
                    !.podmanStorageReady = FALSE,
                    !.kvmPrepared = FALSE,
                    !.initAttempts = 1]

StartDocker ==
    /\ s.container = "running"
    /\ s.systemdActive
    /\ s.initComplete
    /\ DockerAvailable
    /\ s.dockerStarts = 0
    /\ s' = [s EXCEPT !.dockerReady = TRUE,
                    !.dockerStarts = 1]

DockerStartRejected ==
    /\ s.container = "running"
    /\ s.systemdActive
    /\ s.initComplete
    /\ ~DockerAvailable
    /\ s' = [s EXCEPT !.initFailed = TRUE]

EnableLinger ==
    /\ s.container = "running"
    /\ s.initComplete
    /\ s.dockerReady
    /\ s.dbusReady
    /\ s.logindReady
    /\ ~s.linger
    /\ s' = [s EXCEPT !.linger = TRUE]

StartUserManager ==
    /\ s.container = "running"
    /\ s.initComplete
    /\ s.dockerReady
    /\ s.dbusReady
    /\ s.logindReady
    /\ s.linger
    /\ s.vscodeUID = 1000
    /\ ~s.userManager
    /\ s' = [s EXCEPT !.runtimeOwner = "vscode",
                    !.userManager = TRUE]

RegisterProbeUnit ==
    /\ s.userManager
    /\ ~s.probeUnitRegistered
    /\ s' = [s EXCEPT !.probeUnitRegistered = TRUE]

StartProbeUnit ==
    /\ s.userManager
    /\ s.probeUnitRegistered
    /\ ~s.probeUnitActive
    /\ s' = [s EXCEPT !.probeUnitActive = TRUE]

CheckPodmanSmoke ==
    /\ s.runtimeSmokeStarted
    /\ s.dockerSmokeResult = "pass"
    /\ ~s.podmanSmokeChecked
    /\ s' = [s EXCEPT !.podmanSmokeChecked = TRUE,
                    !.podmanSmokeResult = IF s.podmanStorageReady THEN "pass" ELSE "fail"]

CheckKvmSmoke ==
    /\ s.runtimeSmokeStarted
    /\ s.podmanSmokeResult = "pass"
    /\ ~s.kvmSmokeChecked
    /\ s' = [s EXCEPT !.kvmSmokeChecked = TRUE,
                    !.kvmSmokeResult = IF ~KvmDevicePresent
                                      THEN "not-run"
                                      ELSE IF s.kvmPrepared THEN "pass" ELSE "fail"]

CheckDockerSmoke ==
    /\ s.runtimeSmokeStarted
    /\ s.formulaInstalled
    /\ ~s.brewUnitRegistered
    /\ ~s.dockerSmokeChecked
    /\ s' = [s EXCEPT !.dockerSmokeChecked = TRUE,
                    !.dockerSmokeResult = IF s.dockerReady THEN "pass" ELSE "fail"]

InstallFormula ==
    /\ s.userManager
    /\ ~s.runtimeSmokeStarted
    /\ ~s.dockerSmokeChecked
    /\ ~s.formulaInstalled
    /\ s' = [s EXCEPT !.formulaInstalled = TRUE,
                    !.t3Home = "scratch"]

StartBrewService ==
    /\ s.container = "running"
    /\ s.userManager
    /\ s.formulaInstalled
    /\ s.t3Home = "scratch"
    /\ ~s.runtimeSmokeStarted
    /\ ~s.dockerSmokeChecked
    /\ ~s.brewActive
    /\ s' = [s EXCEPT !.brewUnitRegistered = TRUE,
                    !.brewUnitFailed = FALSE,
                    !.brewActive = TRUE,
                    !.brewRestarts = 0,
                    !.brewPids = 1,
                    !.tcpListeners = 1]

RestartBrewService ==
    /\ s.brewActive
    /\ ~s.runtimeSmokeStarted
    /\ s.brewRestarts = 0
    /\ s' = [s EXCEPT !.brewRestarts = 1,
                    !.brewPids = 1,
                    !.tcpListeners = 1]

DetachShell ==
    /\ s.shellAttached
    /\ s.brewActive
    /\ s' = [s EXCEPT !.shellAttached = FALSE,
                    !.shellDetachedWithBrew = TRUE]

AttachShell ==
    /\ ~s.shellAttached
    /\ s.userManager
    /\ s' = [s EXCEPT !.shellAttached = TRUE,
                    !.shellDetachedWithBrew = FALSE]

StopBrewService ==
    /\ s.brewUnitRegistered
    /\ ~s.runtimeSmokeStarted
    /\ s' = [s EXCEPT !.brewUnitRegistered = FALSE,
                    !.brewLifecycleComplete = TRUE,
                    !.brewUnitFailed = FALSE,
                    !.brewActive = FALSE,
                    !.brewPids = 0,
                    !.tcpListeners = 0,
                    !.t3Home = "absent",
                    !.shellDetachedWithBrew = FALSE]

BeginRuntimeSmoke ==
    /\ s.container = "running"
    /\ s.generation = 1
    /\ s.userManager
    /\ s.dockerReady
    /\ s.formulaInstalled
    /\ s.brewLifecycleComplete
    /\ ~s.brewUnitRegistered
    /\ ~s.runtimeSmokeStarted
    /\ s' = [s EXCEPT !.runtimeSmokeStarted = TRUE]

AutoStartPersistedBrew ==
    /\ s.userManager
    /\ s.brewUnitRegistered
    /\ ~s.brewActive
    /\ s.formulaInstalled
    /\ s.t3Home = "scratch"
    /\ s' = [s EXCEPT !.brewActive = TRUE,
                    !.brewUnitFailed = FALSE,
                    !.brewPids = 1,
                    !.tcpListeners = 1]

PersistedBrewCannotRun ==
    /\ s.userManager
    /\ s.brewUnitRegistered
    /\ ~s.brewActive
    /\ ~s.formulaInstalled
    /\ s' = [s EXCEPT !.brewUnitFailed = TRUE]

StopContainer ==
    /\ s.container = "running"
    /\ s' = [s EXCEPT !.container = "stopped",
                    !.pid1 = "none",
                    !.systemdActive = FALSE,
                    !.dbusReady = FALSE,
                    !.logindReady = FALSE,
                    !.runtimeOwner = "none",
                    !.userManager = FALSE,
                    !.dockerReady = FALSE,
                    !.dockerStarts = 0,
                    !.podmanStorageReady = FALSE,
                    !.podmanSmokeChecked = FALSE,
                    !.podmanSmokeResult = "pending",
                    !.kvmPrepared = FALSE,
                    !.kvmSmokeChecked = FALSE,
                    !.kvmSmokeResult = "pending",
                    !.dockerSmokeChecked = FALSE,
                    !.dockerSmokeResult = "pending",
                    !.runtimeSmokeStarted = FALSE,
                    !.probeUnitActive = FALSE,
                    !.brewActive = FALSE,
                    !.brewPids = 0,
                    !.tcpListeners = 0,
                    !.shellAttached = FALSE,
                    !.shellDetachedWithBrew = FALSE,
                    !.initComplete = FALSE,
                    !.initFailed = FALSE,
                    !.initAttempts = 0]

RestartContainer ==
    /\ Flavor = "wolfi-systemd"
    /\ s.container = "stopped"
    /\ CgroupDelegated
    /\ s' = [s EXCEPT !.container = "running",
                    !.pid1 = "systemd",
                    !.systemdActive = TRUE,
                    !.dbusReady = FALSE,
                    !.logindReady = FALSE,
                    !.runtimeOwner = "none",
                    !.userManager = FALSE,
                    !.dockerReady = FALSE,
                    !.dockerStarts = 0,
                    !.podmanStorageReady = FALSE,
                    !.podmanSmokeChecked = FALSE,
                    !.podmanSmokeResult = "pending",
                    !.kvmPrepared = FALSE,
                    !.kvmSmokeChecked = FALSE,
                    !.kvmSmokeResult = "pending",
                    !.dockerSmokeChecked = FALSE,
                    !.dockerSmokeResult = "pending",
                    !.runtimeSmokeStarted = FALSE,
                    !.probeUnitActive = FALSE,
                    !.brewActive = FALSE,
                    !.brewPids = 0,
                    !.tcpListeners = 0,
                    !.initComplete = FALSE,
                    !.initFailed = FALSE,
                    !.initAttempts = 0]

RecreateContainer ==
    /\ Flavor = "wolfi-systemd"
    /\ s.container = "stopped"
    /\ s.generation < 2
    /\ CgroupDelegated
    /\ s' = [s EXCEPT !.container = "created",
                    !.generation = s.generation + 1,
                    !.pid1 = "none",
                    !.systemdActive = FALSE,
                    !.dbusReady = FALSE,
                    !.logindReady = FALSE,
                    !.runtimeOwner = "none",
                    !.linger = FALSE,
                    !.userManager = FALSE,
                    !.dockerReady = FALSE,
                    !.dockerStarts = 0,
                    !.podmanStorageReady = FALSE,
                    !.podmanSmokeChecked = FALSE,
                    !.podmanSmokeResult = "pending",
                    !.kvmPrepared = FALSE,
                    !.kvmSmokeChecked = FALSE,
                    !.kvmSmokeResult = "pending",
                    !.dockerSmokeChecked = FALSE,
                    !.dockerSmokeResult = "pending",
                    !.probeUnitActive = FALSE,
                    !.formulaInstalled = FALSE,
                    !.brewActive = FALSE,
                    !.brewLifecycleComplete = FALSE,
                    !.runtimeSmokeStarted = FALSE,
                    !.brewPids = 0,
                    !.tcpListeners = 0,
                    !.shellAttached = FALSE,
                    !.shellDetachedWithBrew = FALSE,
                    !.t3Home = "absent",
                    !.initComplete = FALSE,
                    !.initFailed = FALSE,
                    !.initAttempts = 0]

RemoveContainer ==
    /\ s.container \in {"stopped", "failed"}
    /\ s' = [s EXCEPT !.container = "absent",
                    !.pid1 = "none",
                    !.systemdActive = FALSE,
                    !.userManager = FALSE,
                    !.dockerReady = FALSE,
                    !.probeUnitActive = FALSE,
                    !.brewActive = FALSE,
                    !.brewPids = 0,
                    !.tcpListeners = 0]

PartialCleanupFailure ==
    /\ s.container = "stopped"
    /\ s' = [s EXCEPT !.cleanupError = TRUE]

DeleteOwnedTestVolume ==
    /\ s.container = "absent"
    /\ s.volumeOwner = "this-run"
    /\ ~s.volumeDeleted
    /\ s' = [s EXCEPT !.homeVolume = FALSE,
                    !.homeSeeded = FALSE,
                    !.volumeDeleted = TRUE,
                    !.deletedVolumeOwner = s.volumeOwner,
                    !.volumeOwner = "none"]

Done ==
    /\ s.container = "failed" \/ (s.container = "absent" /\ s.volumeDeleted)
    /\ UNCHANGED vars

Next ==
    \/ CreateContainer
    \/ RejectVolumeCollision
    \/ BootSystemd
    \/ BootLegacyWolfi
    \/ BootRejected
    \/ StartDBus
    \/ StartLogind
    \/ InitializeHomeSuccess
    \/ InitializeHomeFailureIgnored
    \/ InitializeHomeFailureRejected
    \/ StartDocker
    \/ DockerStartRejected
    \/ EnableLinger
    \/ StartUserManager
    \/ RegisterProbeUnit
    \/ StartProbeUnit
    \/ CheckPodmanSmoke
    \/ CheckKvmSmoke
    \/ CheckDockerSmoke
    \/ InstallFormula
    \/ StartBrewService
    \/ RestartBrewService
    \/ AutoStartPersistedBrew
    \/ PersistedBrewCannotRun
    \/ DetachShell
    \/ AttachShell
    \/ StopBrewService
    \/ BeginRuntimeSmoke
    \/ StopContainer
    \/ RestartContainer
    \/ RecreateContainer
    \/ RemoveContainer
    \/ PartialCleanupFailure
    \/ DeleteOwnedTestVolume
    \/ Done

Spec ==
    Init
    /\ [][Next]_vars
    /\ WF_vars(BootSystemd \/ BootLegacyWolfi \/ BootRejected)
    /\ WF_vars(StartDBus)
    /\ WF_vars(StartLogind)
    /\ WF_vars(InitializeHomeSuccess \/ InitializeHomeFailureIgnored \/ InitializeHomeFailureRejected)
    /\ WF_vars(StartDocker \/ DockerStartRejected)
    /\ WF_vars(EnableLinger)
    /\ WF_vars(StartUserManager)
    /\ WF_vars(CheckPodmanSmoke)
    /\ WF_vars(CheckKvmSmoke)
    /\ WF_vars(CheckDockerSmoke)

TypeOK ==
    /\ s.container \in {"absent", "created", "running", "stopped", "failed"}
    /\ s.generation \in 0..2
    /\ s.pid1 \in {"none", "entrypoint", "systemd"}
    /\ s.systemdActive \in BOOLEAN
    /\ s.dbusReady \in BOOLEAN
    /\ s.logindReady \in BOOLEAN
    /\ s.cgroupNamespace \in {"private", "host"}
    /\ s.vscodeUID \in {1000, 2000}
    /\ s.runtimeOwner \in {"none", "vscode", "other"}
    /\ s.homeVolume \in BOOLEAN
    /\ s.homeSeeded \in BOOLEAN
    /\ s.initComplete \in BOOLEAN
    /\ s.initFailed \in BOOLEAN
    /\ s.initAttempts \in 0..1
    /\ s.linger \in BOOLEAN
    /\ s.userManager \in BOOLEAN
    /\ s.dockerReady \in BOOLEAN
    /\ s.dockerStarts \in 0..1
    /\ s.podmanStorageReady \in BOOLEAN
    /\ s.podmanSmokeChecked \in BOOLEAN
    /\ s.podmanSmokeResult \in {"pending", "pass", "fail"}
    /\ s.kvmPrepared \in BOOLEAN
    /\ s.kvmSmokeChecked \in BOOLEAN
    /\ s.kvmSmokeResult \in {"pending", "not-run", "pass", "fail"}
    /\ s.dockerSmokeChecked \in BOOLEAN
    /\ s.dockerSmokeResult \in {"pending", "pass", "fail"}
    /\ s.probeUnitRegistered \in BOOLEAN
    /\ s.probeUnitActive \in BOOLEAN
    /\ s.formulaInstalled \in BOOLEAN
    /\ s.brewUnitRegistered \in BOOLEAN
    /\ s.brewLifecycleComplete \in BOOLEAN
    /\ s.runtimeSmokeStarted \in BOOLEAN
    /\ s.brewUnitFailed \in BOOLEAN
    /\ s.brewActive \in BOOLEAN
    /\ s.brewRestarts \in 0..1
    /\ s.brewPids \in 0..1
    /\ s.tcpListeners \in 0..1
    /\ s.shellAttached \in BOOLEAN
    /\ s.shellDetachedWithBrew \in BOOLEAN
    /\ s.t3Home \in {"absent", "scratch"}
    /\ s.volumeOwner \in {"none", "this-run", "other"}
    /\ s.volumeDeleted \in BOOLEAN
    /\ s.deletedVolumeOwner \in {"none", "this-run", "other"}
    /\ s.cleanupError \in BOOLEAN

SystemdPid1 ==
    (Flavor = "wolfi" /\ s.container = "running") =>
      (s.pid1 = "entrypoint" /\ ~s.systemdActive)

OptInUsesSystemdPid1 ==
    Flavor = "wolfi-systemd" /\ s.container = "running" => s.pid1 = "systemd" /\ s.systemdActive

InitCompleteRequiresSeed == s.initComplete => s.homeSeeded

ManagerRequiresBootstrap ==
    s.userManager =>
      s.initComplete /\ s.homeSeeded /\ s.dbusReady /\ s.logindReady /\
      s.linger /\ s.runtimeOwner = "vscode" /\ s.vscodeUID = 1000 /\ s.dockerReady

NoWorkloadBeforeManager ==
    (s.probeUnitActive \/ s.brewActive) => s.userManager /\ s.container = "running"

ProbeServiceRunsAsVscode == s.probeUnitActive => s.vscodeUID = 1000

BrewServiceContract ==
    s.brewActive =>
      s.userManager /\ s.homeSeeded /\ s.formulaInstalled /\ s.brewUnitRegistered /\
      s.t3Home = "scratch" /\ s.vscodeUID = 1000 /\
      s.brewPids = 1 /\ s.tcpListeners = 1

NoDuplicateDocker == s.dockerStarts \in 0..1

PodmanSmokeEvidence == s.podmanSmokeResult = "pass" =>
    s.userManager /\ s.podmanStorageReady /\ s.runtimeOwner = "vscode" /\ s.vscodeUID = 1000

KvmNotRunOnlyWhenUnavailable == s.kvmSmokeResult = "not-run" => ~KvmDevicePresent

KvmPassRequiresPreparation == s.kvmSmokeResult = "pass" => KvmDevicePresent /\ s.kvmPrepared

DockerSmokeEvidence == s.dockerSmokeResult = "pass" => s.dockerReady

DetachedBrewRemainsActive == s.shellDetachedWithBrew => s.brewActive

StoppedContainerHasNoLiveServices ==
    s.container = "stopped" =>
      ~s.systemdActive /\ ~s.userManager /\ ~s.dockerReady /\
      ~s.probeUnitActive /\ ~s.brewActive /\ s.brewPids = 0 /\ s.tcpListeners = 0

PrivateCgroupNamespace == s.cgroupNamespace = "private"

VscodeUIDPinned == s.vscodeUID = 1000

PersistentHomeSeed == s.homeSeeded => s.homeVolume

VolumeDeleteOwned == s.volumeDeleted => s.deletedVolumeOwner = "this-run"

NoVolumeDeleteWhileContainerExists == s.volumeDeleted => s.container = "absent"

StartupSettles ==
    (s.container = "created" /\ Flavor = "wolfi-systemd") ~>
      (s.userManager \/ s.initFailed \/ s.container \in {"failed", "stopped", "absent"})

RuntimeSmokePasses ==
    s.runtimeSmokeStarted ~>
      ((s.podmanSmokeResult = "pass" /\ s.dockerSmokeResult = "pass" /\
        s.kvmSmokeChecked /\
        (IF KvmDevicePresent THEN s.kvmSmokeResult = "pass" ELSE s.kvmSmokeResult = "not-run")) \/
       s.container \in {"stopped", "failed", "absent"})
==================================================================================
