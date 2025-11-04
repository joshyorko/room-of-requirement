[![Open in DevPod!](https://devpod.sh/assets/open-in-devpod.svg)](https://devpod.sh/open#https://github.com/joshyorko/room-of-requirement)

<!--
 _   _                 _                 _   _                 _           _   _             _   _
| | | | ___  _ __ ___ | |__   ___ _ __  | \ | | _____      __ | | ___  ___| |_| |_ ___ _ __ | |_| |_ ___  _ __
| |_| |/ _ \| '_ ` _ \| '_ \ / _ \ '__| |  \| |/ _ \ \ /\ / / | |/ _ \/ __| __| __/ _ \ '_ \| __| __/ _ \| '__|
|  _  | (_) | | | | | | |_) |  __/ |    | |\  |  __/\ V  V /  | |  __/ (__| |_| ||  __/ | | | |_| || (_) | |
|_| |_|\___/|_| |_| |_|_.__/ \___|_|    |_| \_|\___| \_/\_/   |_|\___|\___|\__|\__\___|_| |_|\__|\__\___/|_|
-- Room of Requirement --
-- DevContainer Setup --
-- Ubuntu Noble + Docker (host socket) + Zsh + K3d + K9s + uv --
-- VS Code Extensions: Containers, Sema4AI, GitHub Actions --
-- Post-create installs: k3d, k9s, uv --
-- Default shell: zsh (with Oh My Zsh) --
-- Docker socket from host, not privileged mode --
-- Remote user: vscode --
-- All the magic you need for cloud-native dev! --

--
-- Quick Start --
1. Open in VS Code with Dev Containers extension
2. Let it build and install everything automagically
3. Start coding your next magical project!
-->

# **Room of Requirement**

> _A magical devcontainer for all your cloud-native needs!_

---

## **Features**
- **Ubuntu Noble** base
- **Docker (host socket)** for container magic
- **Zsh** (with Oh My Zsh)
- **k3d** (K3s in Docker)
- **k9s** (Kubernetes CLI UI)
- **uv** (Python package manager)
- **VS Code Extensions**: Containers, Sema4AI, GitHub Actions

---

## **Quick Start**
1. Open this folder in VS Code
2. Reopen in Container (Dev Containers extension)
3. Wait for setup to finish
4. Start coding your next magical project!

---

## **Details**
- **Remote User:** `vscode`
- **Default Shell:** `zsh`
- **Docker:** Host socket (docker-outside-of-docker feature)
- **Post-create Installs:** k3d, k9s, uv

---

## **Why Room of Requirement?**
Because every developer deserves a workspace that adapts to their needs—just like magic.

---

## **Customization**
Feel free to edit `.devcontainer/devcontainer.json` to add more features or extensions!

---

## **Automated Maintenance**
- Daily RCC-powered maintenance keeps `.devcontainer/` assets and GitHub Actions workflows up to date.
- Review `automation/maintenance-robot/README.md` for details on allowlists, task entrypoints, and manual execution instructions.

The automation workflow lives in `.github/workflows/rcc-maintenance.yml` and auto-commits any approved updates using the repository `GITHUB_TOKEN`.

---

## **Happy Coding!**

```shell
$ zsh
$ k3d --version
$ k9s version
$ uv --version
```
