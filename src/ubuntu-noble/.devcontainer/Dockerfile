# syntax=docker/dockerfile:1.28@sha256:bb22d9815c728170f72750f4e5b0d672e06176142e1d602c7e66c050100b7e5b

ARG ROR_GO_BUILDER_IMAGE=golang:1.27.3-trixie@sha256:1896654cfc5c2b5ad74c07f29cb36f5d2d1cbed42e3054070fbfe444e521e83c

# Rebuild embedded Go dependencies before any runtime image is assembled.
FROM ${ROR_GO_BUILDER_IMAGE} AS container-tools-build
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 && \
    rm -rf /var/lib/apt/lists/*
COPY src/common/container-tools /build/container-tools
ENV GOPATH=/root/go
RUN --mount=type=cache,target=/root/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    python3 /build/container-tools/build.py --output /out

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae

ARG TARGETARCH

LABEL maintainer="Josh Yorko <joshua.yorko@gmail.com>"
LABEL org.opencontainers.image.title="Room of Requirement Ubuntu Noble"
LABEL org.opencontainers.image.description="Codespaces-focused Room of Requirement DevContainer variant"
LABEL org.opencontainers.image.source="https://github.com/joshyorko/room-of-requirement"
LABEL devcontainer.metadata='[{"remoteUser":"vscode","overrideCommand":false,"privileged":true,"runArgs":["--privileged"],"remoteEnv":{"SHELL":"/bin/zsh","DOCKER_BUILDKIT":"1"}}]'

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew \
    HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar \
    HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1 \
    PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:${PATH}"

USER 0

RUN apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        file \
        fuse-overlayfs \
        git \
        gnupg \
        just \
        jq \
        locales \
        ncurses-bin \
        openssh-client \
        procps \
        sudo \
        tzdata \
        unzip \
        util-linux \
        wget \
        zsh && \
    locale-gen C.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

COPY src/common/ghostty /usr/share/ror/ghostty
COPY src/common/scripts/install-ghostty-support.sh /usr/local/bin/install-ghostty-support.sh
RUN chmod +x /usr/local/bin/install-ghostty-support.sh && \
    /usr/local/bin/install-ghostty-support.sh

COPY --from=container-tools-build /out /usr/local/share/ror/container-tools
RUN /usr/local/share/ror/container-tools/install.sh

RUN groupadd -f docker && \
    usermod -aG docker vscode

RUN mkdir -p /home/linuxbrew && \
    chown vscode:vscode /home/linuxbrew && \
    touch /.dockerenv && \
    su - vscode -c "NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" && \
    su - vscode -c "/home/linuxbrew/.linuxbrew/bin/brew update --force" && \
    su - vscode -c "/home/linuxbrew/.linuxbrew/bin/brew install starship mise zoxide" && \
    su - vscode -c "mkdir -p \
        /home/linuxbrew/.linuxbrew/var/homebrew/linked \
        /home/linuxbrew/.linuxbrew/var/homebrew/locks \
        /home/linuxbrew/.linuxbrew/Cellar \
        /home/linuxbrew/.linuxbrew/Caskroom" && \
    chmod 755 /home/linuxbrew && \
    chmod 775 /home/linuxbrew/.linuxbrew && \
    git config --system --add safe.directory /home/linuxbrew/.linuxbrew/Homebrew

RUN mkdir -p \
        /usr/local/share/mise \
        /home/vscode/.cache/mise \
        /home/vscode/.local/share/mise \
        /home/vscode/.config/mise \
        /etc/docker \
        /usr/local/etc/vscode-dev-containers \
        /usr/share/ror/config \
        /workspaces && \
    chown -R vscode:vscode /usr/local/share/mise /home/vscode/.cache /home/vscode/.local /home/vscode/.config /workspaces && \
    chmod 755 /workspaces

COPY src/common/first-run-notice.txt /usr/local/etc/vscode-dev-containers/first-run-notice.txt
COPY --chown=vscode:vscode src/common/config/.zshrc /usr/share/ror/config/.zshrc
COPY --chown=vscode:vscode src/common/config/.bashrc /usr/share/ror/config/.bashrc
COPY --chown=vscode:vscode src/common/config/.zshrc /home/vscode/.zshrc
COPY --chown=vscode:vscode src/common/config/.bashrc /home/vscode/.bashrc
COPY --chown=vscode:vscode src/common/config/starship.toml /usr/share/ror/config/starship.toml
COPY --chown=vscode:vscode src/common/config/starship.toml /home/vscode/.config/starship.toml
COPY --chown=vscode:vscode src/common/config/mise.toml /usr/share/ror/config/mise.toml
COPY --chown=vscode:vscode src/common/config/mise.toml /home/vscode/.config/mise/config.toml
COPY src/common/config/docker-daemon.json /etc/docker/daemon.json
COPY --chown=vscode:vscode src/common/post-create.sh /usr/local/bin/devcontainer-post-create.sh
COPY --chown=vscode:vscode src/common/scripts/mise-seed-cache.sh /usr/local/bin/mise-seed-cache.sh
COPY --chown=vscode:vscode src/common/scripts/seed-vscode-home.sh /usr/local/bin/seed-vscode-home.sh
COPY --chown=vscode:vscode src/common/scripts/ror-docker-start.sh /usr/local/bin/ror-docker-start.sh
COPY --chown=vscode:vscode src/common/scripts/ror-brew-download.sh /usr/local/bin/ror-brew-download.sh
COPY src/common/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=vscode:vscode src/common/brew /usr/share/ror/brew
COPY --chown=vscode:vscode src/common/justfile /usr/share/ror/justfile

RUN chmod +x \
        /usr/local/bin/devcontainer-post-create.sh \
        /usr/local/bin/mise-seed-cache.sh \
        /usr/local/bin/seed-vscode-home.sh \
        /usr/local/bin/ror-docker-start.sh \
        /usr/local/bin/ror-brew-download.sh \
        /usr/local/bin/entrypoint.sh && \
    chmod 644 /usr/share/ror/justfile && \
    printf '#!/bin/bash\nexec just --justfile /usr/share/ror/justfile --working-directory /usr/share/ror "$@"\n' > /usr/local/bin/ujust && \
    chmod +x /usr/local/bin/ujust

USER 1000

ENV HOME=/home/vscode \
    SHELL=/bin/zsh \
    PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:${PATH}"

WORKDIR /workspaces

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
