# syntax=docker/dockerfile:1.7
# Modular DevContainer Architecture: Wolfi OS + Homebrew Base
# Tools installed via devcontainer features, not Dockerfile
# Spec: specs/001-modular-devcontainer-architecture/

# ============================================================================
# ARG PINS: Base image version
# ============================================================================
ARG WOLFI_BASE_IMAGE=cgr.dev/chainguard/wolfi-base:latest

# ============================================================================
# STAGE 1: Base Image with System Packages
# ============================================================================
FROM ${WOLFI_BASE_IMAGE} AS base

LABEL maintainer="Josh Yorke <josh@example.com>"
LABEL org.opencontainers.image.title="Room of Requirement"
LABEL org.opencontainers.image.description="Modular DevContainer with Wolfi OS - tools via features"

# UTF-8 locale and timezone
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC

# Install system packages (minimal set for devcontainer features to work)
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    git \
    glibc \
    libstdc++ \
    openssh \
    posix-libc-utils \
    shadow \
    sudo \
    tini \
    wget \
    zsh

# ============================================================================
# STAGE 2: User Setup
# ============================================================================
FROM base AS users

# Create vscode user (UID 1000)
RUN groupadd -g 1000 vscode && \
    useradd -m -u 1000 -g vscode -s /bin/zsh vscode && \
    echo "vscode ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/vscode && \
    chmod 0440 /etc/sudoers.d/vscode

# Create linuxbrew user for Homebrew ownership
RUN groupadd -g 2000 linuxbrew && \
    useradd -m -u 2000 -g linuxbrew linuxbrew && \
    echo "linuxbrew ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/linuxbrew && \
    chmod 0440 /etc/sudoers.d/linuxbrew

# ============================================================================
# STAGE 3: Homebrew Foundation (required for ror-cli-tools feature)
# ============================================================================
FROM users AS homebrew

# Install Homebrew build dependencies
RUN apk add --no-cache \
    build-base \
    libffi-dev \
    openssl-dev \
    ruby-dev \
    procps

# Install Homebrew
RUN mkdir -p /home/linuxbrew/.linuxbrew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew && \
    su - linuxbrew -c 'git clone https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew' && \
    su - linuxbrew -c 'mkdir -p /home/linuxbrew/.linuxbrew/bin' && \
    su - linuxbrew -c 'ln -s ../Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew' && \
    su - linuxbrew -c '/home/linuxbrew/.linuxbrew/bin/brew update --force --quiet'

# Homebrew environment
ENV HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew \
    HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar \
    HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1

# Configure Homebrew permissions for vscode user
RUN mkdir -p \
    /home/linuxbrew/.linuxbrew/var/homebrew/linked \
    /home/linuxbrew/.linuxbrew/var/homebrew/locks \
    /home/linuxbrew/.linuxbrew/Cellar \
    /home/linuxbrew/.linuxbrew/Caskroom && \
    chmod -R g+rwX /home/linuxbrew/.linuxbrew && \
    chgrp -R vscode /home/linuxbrew/.linuxbrew && \
    chmod 775 /home/linuxbrew/.linuxbrew

# ============================================================================
# STAGE 4: Final Image
# ============================================================================
FROM homebrew AS final

# Copy shell configuration
COPY --chown=vscode:vscode .devcontainer/config/.zshrc /home/vscode/.zshrc

# Create workspace and cache directories
RUN mkdir -p \
    /home/vscode/.cache \
    /home/vscode/.local/share \
    /home/vscode/.config \
    /workspaces && \
    chown -R vscode:vscode /home/vscode /workspaces && \
    chmod 755 /workspaces

# Switch to vscode user
USER vscode

# Environment
ENV HOME=/home/vscode \
    SHELL=/bin/zsh \
    PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:${PATH}"

WORKDIR /workspaces

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD echo "OK" || exit 1

CMD ["/bin/zsh"]
