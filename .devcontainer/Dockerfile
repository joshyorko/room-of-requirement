# syntax=docker/dockerfile:1.7
# Modular DevContainer Architecture: Wolfi OS + Homebrew Base
# Tools installed via devcontainer features, not Dockerfile
# Spec: specs/001-modular-devcontainer-architecture/

# ============================================================================
# ARG PINS: Base image version
# ============================================================================
# Wolfi base image - kept current by maintenance robot for security patches
ARG WOLFI_BASE_IMAGE=cgr.dev/chainguard/wolfi-base:latest

# ============================================================================
# STAGE 1: Base Image with System Packages
# ============================================================================
FROM ${WOLFI_BASE_IMAGE} AS base

LABEL maintainer="Josh Yorko <joshua.yorko@gmail.com>"
LABEL org.opencontainers.image.title="Room of Requirement"
LABEL org.opencontainers.image.description="Modular DevContainer with Wolfi OS - tools via features"
LABEL org.opencontainers.image.source="https://github.com/joshyorko/room-of-requirement"

# UTF-8 locale and timezone
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC

# Install system packages (minimal set for devcontainer features to work)
# Security: Use fixed versions where available, keep minimal footprint
# NOTE: Wolfi uses native glibc (not musl like Alpine), so gcompat is NOT needed
# VS Code Server works directly without compatibility layers
RUN apk add --no-cache \
    bash \
    ca-certificates \
    coreutils \
    curl \
    findutils \
    git \
    glibc \
    glibc-locales \
    just \
    libstdc++ \
    openssh-client \
    posix-libc-utils \
    procps \
    shadow \
    sudo \
    tini \
    util-linux \
    wget \
    zsh \
    # Official Wolfi Docker-in-Docker packages (from Chainguard)
    docker \
    docker-compose \
    docker-dind \
    dockerd-oci-entrypoint \
    # Playwright/Browser dependencies (headless Chromium support)
    # Note: Some deps like atk, gtk-3 aren't in Wolfi - Playwright may show warnings
    alsa-lib \
    at-spi2-core \
    cairo \
    cups-libs \
    dbus-libs \
    gdk-pixbuf \
    libdrm \
    libx11 \
    libxcb \
    libxcomposite \
    libxcursor \
    libxdamage \
    libxext \
    libxfixes \
    libxkbcommon \
    libxrandr \
    libxshmfence \
    mesa \
    mesa-gbm \
    nss \
    pango && \
    # Enable docker compose plugin (V2 syntax) by symlinking to plugin directory
    ln -sf /usr/bin/docker-compose /usr/libexec/docker/cli-plugins/docker-compose && \
    # Verify critical security tools
    curl --version && \
    git --version

# ============================================================================
# STAGE 2: User Setup
# ============================================================================
FROM base AS users

# Create docker group and vscode user (UID 1000)
RUN groupadd -g 999 docker && \
    groupadd -g 1000 vscode && \
    useradd -m -u 1000 -g vscode -G docker -s /bin/zsh vscode && \
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
# Security: Only install what's strictly necessary for Homebrew to function
RUN apk add --no-cache \
    build-base \
    libffi-dev \
    openssl \
    openssl-dev \
    ruby-dev \
    procps \
    git-daemon && \
    # Verify OpenSSL for security
    openssl version

# Install Homebrew using the OFFICIAL installer (same as Universal Blue)
# This ensures proper git remote setup and works correctly with brew update
RUN mkdir -p /home/linuxbrew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew && \
    # Create .dockerenv to skip some interactive checks in the installer
    touch /.dockerenv && \
    # Run official Homebrew installer as linuxbrew user
    su - linuxbrew -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' && \
    # Run initial update to populate formulae
    su - linuxbrew -c '/home/linuxbrew/.linuxbrew/bin/brew update --force' && \
    # Configure git safe directory for all users
    git config --system --add safe.directory /home/linuxbrew/.linuxbrew/Homebrew

# Homebrew environment
ENV HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew \
    HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar \
    HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew \
    HOMEBREW_NO_ANALYTICS=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1

# Configure Homebrew permissions for vscode user
# vscode user needs full write access to Homebrew repo for `brew update`
RUN mkdir -p \
    /home/linuxbrew/.linuxbrew/var/homebrew/linked \
    /home/linuxbrew/.linuxbrew/var/homebrew/locks \
    /home/linuxbrew/.linuxbrew/Cellar \
    /home/linuxbrew/.linuxbrew/Caskroom && \
    # Change ownership to vscode so brew update works (git fetch needs write access)
    chown -R vscode:vscode /home/linuxbrew/.linuxbrew && \
    chmod -R u+rwX /home/linuxbrew/.linuxbrew && \
    chmod 775 /home/linuxbrew/.linuxbrew

# ============================================================================
# STAGE 3.5: Install Core Shell Tools (mise, starship, zoxide, nushell)
# ============================================================================
# Pre-install foundational shell/dev tools so they're baked into the image
# These are required by .zshrc and should be available immediately
FROM homebrew AS core-tools

# Copy core.Brewfile for installation
COPY .devcontainer/brew/core.Brewfile /tmp/core.Brewfile

USER vscode

# Install core shell tools via Homebrew using the Brewfile
RUN /home/linuxbrew/.linuxbrew/bin/brew bundle --file=/tmp/core.Brewfile && \
    /home/linuxbrew/.linuxbrew/bin/brew cleanup

# Configure mise with default language runtimes
RUN /home/linuxbrew/.linuxbrew/bin/mise use -g node@lts python@latest go@latest

USER root

# ============================================================================
# STAGE 4: Final Image
# ============================================================================
FROM core-tools AS final

# Security: Update packages after multi-stage build
RUN apk update && \
    apk add --no-cache --upgrade \
    ca-certificates \
    openssl && \
    apk cache clean && \
    # Remove gcompat from world file if present (VS Code may try to add it)
    # Wolfi uses native glibc, not musl - gcompat is not needed and not available
    # Use broader pattern to catch gcompat with or without version constraints
    sed -i '/gcompat/d' /etc/apk/world 2>/dev/null || true

# Copy first run notice for VS Code to display
RUN mkdir -p /usr/local/etc/vscode-dev-containers
COPY .devcontainer/first-run-notice.txt /usr/local/etc/vscode-dev-containers/first-run-notice.txt

# Copy shell configuration (to /tmp for postCreate restore after features may overwrite it)
COPY --chown=vscode:vscode .devcontainer/config/.zshrc /tmp/.zshrc-ror
COPY --chown=vscode:vscode .devcontainer/config/.zshrc /home/vscode/.zshrc
COPY --chown=vscode:vscode .devcontainer/config/.bashrc /tmp/.bashrc-ror
COPY --chown=vscode:vscode .devcontainer/config/.bashrc /home/vscode/.bashrc

# Copy starship configuration (shared by bash and zsh)
COPY --chown=vscode:vscode .devcontainer/config/starship.toml /home/vscode/.config/starship.toml

# Copy post-create script for pre-built image usage
COPY --chown=vscode:vscode .devcontainer/post-create.sh /usr/local/bin/devcontainer-post-create.sh
RUN chmod +x /usr/local/bin/devcontainer-post-create.sh

# Copy Brewfiles for on-demand installation (bbrew TUI selects from these)
COPY --chown=vscode:vscode .devcontainer/brew /tmp/brew

# Copy justfile for Bluefin-style commands (ujust bbrew, etc.)
RUN mkdir -p /usr/share/ror
COPY .devcontainer/justfile /usr/share/ror/justfile
RUN chmod 644 /usr/share/ror/justfile && \
    printf '#!/bin/bash\nexec just --justfile /usr/share/ror/justfile --working-directory /usr/share/ror "$@"\n' > /usr/local/bin/ujust && \
    chmod +x /usr/local/bin/ujust

# Create workspace and cache directories with restricted permissions
RUN mkdir -p \
    /home/vscode/.cache \
    /home/vscode/.local/share \
    /home/vscode/.config \
    /workspaces && \
    chown -R vscode:vscode /home/vscode /workspaces && \
    chmod 755 /workspaces && \
    # Keep build-base/gcc for Homebrew source builds (e.g., bbrew)
    # Remove only Homebrew-specific dev dependencies
    apk del --no-cache \
    libffi-dev \
    openssl-dev \
    ruby-dev || true

# Switch to vscode user
USER vscode

# Environment
ENV HOME=/home/vscode \
    SHELL=/bin/zsh \
    PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:${PATH}"

# Brewfiles are available at /tmp/brew/ for on-demand installation
# Run: ujust bbrew (TUI selector) or ujust brew-install-all (install everything)

WORKDIR /workspaces

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD echo "OK" || exit 1

# Docker-in-Docker entrypoint - official Wolfi/Chainguard dockerd entrypoint
# From dockerd-oci-entrypoint package (ported from docker-library/docker)
ENTRYPOINT ["/usr/bin/dockerd-entrypoint.sh"]
CMD ["sleep", "infinity"]
