# syntax=docker/dockerfile:1.7

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

LABEL maintainer="Josh Yorko <joshua.yorko@gmail.com>"
LABEL org.opencontainers.image.title="Room of Requirement Ubuntu Noble"
LABEL org.opencontainers.image.description="Codespaces-focused Room of Requirement DevContainer variant"
LABEL org.opencontainers.image.source="https://github.com/joshyorko/room-of-requirement"

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

USER root

RUN apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        docker-buildx \
        docker-compose-v2 \
        docker.io \
        file \
        git \
        git-lfs \
        gnupg \
        just \
        locales \
        openssh-client \
        procps \
        sudo \
        tzdata \
        unzip \
        wget \
        zsh && \
    locale-gen C.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -f docker && \
    usermod -aG docker vscode

RUN groupadd -f -g 2000 linuxbrew && \
    id -u linuxbrew >/dev/null 2>&1 || useradd -m -u 2000 -g linuxbrew -s /bin/bash linuxbrew && \
    echo "linuxbrew ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/linuxbrew && \
    chmod 0440 /etc/sudoers.d/linuxbrew && \
    mkdir -p /home/linuxbrew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew && \
    touch /.dockerenv && \
    su - linuxbrew -c "NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" && \
    su - linuxbrew -c "/home/linuxbrew/.linuxbrew/bin/brew update --force" && \
    git config --system --add safe.directory /home/linuxbrew/.linuxbrew/Homebrew

RUN su - linuxbrew -c "/home/linuxbrew/.linuxbrew/bin/brew tap joshyorko/tools && /home/linuxbrew/.linuxbrew/bin/brew tap valkyrie00/bbrew && /home/linuxbrew/.linuxbrew/bin/brew install starship mise zoxide valkyrie00/bbrew/bbrew" && \
    mkdir -p \
        /home/linuxbrew/.linuxbrew/var/homebrew/linked \
        /home/linuxbrew/.linuxbrew/var/homebrew/locks \
        /home/linuxbrew/.linuxbrew/Cellar \
        /home/linuxbrew/.linuxbrew/Caskroom && \
    chown -R vscode:vscode /home/linuxbrew/.linuxbrew && \
    chmod -R u+rwX /home/linuxbrew/.linuxbrew && \
    chmod 755 /home/linuxbrew && \
    chmod 775 /home/linuxbrew/.linuxbrew

RUN mkdir -p \
        /usr/local/share/mise \
        /home/vscode/.cache/mise \
        /home/vscode/.local/share/mise \
        /home/vscode/.config/mise \
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
COPY --chown=vscode:vscode src/common/post-create.sh /usr/local/bin/devcontainer-post-create.sh
COPY --chown=vscode:vscode src/common/scripts/mise-seed-cache.sh /usr/local/bin/mise-seed-cache.sh
COPY --chown=vscode:vscode src/common/scripts/fix-docker-permissions.sh /usr/local/bin/fix-docker-permissions.sh
COPY src/common/scripts/enable-cgroup-memory.sh /usr/local/bin/enable-cgroup-memory.sh
COPY src/common/scripts/fix-cgroup-delegation.sh /usr/local/bin/fix-cgroup-delegation.sh
COPY --chown=vscode:vscode src/common/scripts/ror-brew-download.sh /usr/local/bin/ror-brew-download.sh
COPY src/common/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=vscode:vscode src/common/brew /usr/share/ror/brew
COPY --chown=vscode:vscode src/common/justfile /usr/share/ror/justfile

RUN chmod +x \
        /usr/local/bin/devcontainer-post-create.sh \
        /usr/local/bin/mise-seed-cache.sh \
        /usr/local/bin/fix-docker-permissions.sh \
        /usr/local/bin/enable-cgroup-memory.sh \
        /usr/local/bin/fix-cgroup-delegation.sh \
        /usr/local/bin/ror-brew-download.sh \
        /usr/local/bin/entrypoint.sh && \
    chmod 644 /usr/share/ror/justfile && \
    printf '#!/bin/bash\nexec just --justfile /usr/share/ror/justfile --working-directory /usr/share/ror "$@"\n' > /usr/local/bin/ujust && \
    chmod +x /usr/local/bin/ujust

USER vscode

ENV HOME=/home/vscode \
    SHELL=/bin/zsh \
    PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:${PATH}"

WORKDIR /workspaces

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD echo "OK" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
