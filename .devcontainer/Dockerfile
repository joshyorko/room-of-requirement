# syntax=docker/dockerfile:1.7

ARG KIND_VERSION=v0.30.0
ARG KIND_SHA256=517ab7fc89ddeed5fa65abf71530d90648d9638ef0c4cde22c2c11f8097b8889
ARG K3D_VERSION=v5.8.3
ARG K3D_SHA256=dbaa79a76ace7f4ca230a1ff41dc7d8a5036a8ad0309e9c54f9bf3836dbe853e
ARG K9S_VERSION=v0.50.16
ARG K9S_SHA256=bda09dc030a08987fe2b3bed678b15b52f23d6705e872d561932d4ca07db7818
ARG UV_VERSION=0.9.8
ARG UV_SHA256=950bad4899800ab158db97081b30a601a3ff4237d705756fda8695342cfcc20a
ARG DUCKDB_VERSION=v1.4.1
ARG DUCKDB_SHA256=3e29952507ebd202e8d0e2678df4490689bfc9c86534e240b541791b969df0e1
ARG RCC_VERSION=v18.8.0
ARG RCC_SHA256=bf5b06675adfd6ada7af8e43f4bdc93e6619065b38a6462178fdf8df49477000
ARG ACTION_SERVER_VERSION=2.16.4
ARG ACTION_SERVER_SHA256=beaca29dd529188547c8aa13df9f38aa7e4fc5273f35659f7fadbae0850ee995

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04 AS base

# Copy first run notice for later stage
COPY first-run-notice.txt /tmp/scripts/

FROM base AS system-deps
ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    g++ \
    gcc \
    git \
    git-lfs \
    gnupg \
    libc6 \
    libasound2t64 \
    libasound2-dev \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libxshmfence1 \
    make \
    nano \
    postgresql-client \
    python3 \
    python3-dev \
    python3-venv \
    python3.12-venv \
    sudo \
    unzip \
    vim \
    wget \
    xclip \
    zip && \
    rm -rf /var/lib/apt/lists/*

FROM system-deps AS dev-tools
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    clang \
    cmake \
    cppcheck \
    fd-find \
    fzf \
    gdb \
    libsecret-1-dev \
    lldb \
    llvm \
    software-properties-common \
    valgrind \
    vim-doc \
    xtail && \
    rm -rf /var/lib/apt/lists/*

FROM dev-tools AS cloud-tools
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
ARG KIND_VERSION
ARG KIND_SHA256
ARG K3D_VERSION
ARG K3D_SHA256
ARG K9S_VERSION
ARG K9S_SHA256
ARG UV_VERSION
ARG UV_SHA256
ARG DUCKDB_VERSION
ARG DUCKDB_SHA256
ARG RCC_VERSION
ARG RCC_SHA256
ARG ACTION_SERVER_VERSION
ARG ACTION_SERVER_SHA256

# Install Node.js runtime managed via NodeSource
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-mark hold nodejs && \
    npm install -g npm@latest && \
    rm -rf /var/lib/apt/lists/*

# Install Ansible from official PPA
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-add-repository --yes --update ppa:ansible/ansible && \
    apt-get install -y --no-install-recommends ansible && \
    rm -rf /var/lib/apt/lists/*

# Install remaining automation tooling with checksum verification
RUN set -euo pipefail && \
    tmp_dir="$(mktemp -d)" && \
    trap 'rm -rf "${tmp_dir}"' EXIT && \
    arch="$(uname -m)" && \
    if [[ "${arch}" != "x86_64" && "${arch}" != "amd64" ]]; then \
    echo "Unsupported architecture: ${arch}" >&2; \
    exit 1; \
    fi && \
    curl -fsSLo "${tmp_dir}/kind" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" && \
    echo "${KIND_SHA256}  ${tmp_dir}/kind" | sha256sum --check --status && \
    install -m 0755 "${tmp_dir}/kind" /usr/local/bin/kind && \
    curl -fsSLo "${tmp_dir}/k3d" "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-amd64" && \
    echo "${K3D_SHA256}  ${tmp_dir}/k3d" | sha256sum --check --status && \
    install -m 0755 "${tmp_dir}/k3d" /usr/local/bin/k3d && \
    curl -fsSLo "${tmp_dir}/k9s.tar.gz" "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" && \
    echo "${K9S_SHA256}  ${tmp_dir}/k9s.tar.gz" | sha256sum --check --status && \
    tar -xzf "${tmp_dir}/k9s.tar.gz" -C "${tmp_dir}" k9s && \
    install -m 0755 "${tmp_dir}/k9s" /usr/local/bin/k9s && \
    curl -fsSLo "${tmp_dir}/uv.tar.gz" "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" && \
    echo "${UV_SHA256}  ${tmp_dir}/uv.tar.gz" | sha256sum --check --status && \
    tar -xzf "${tmp_dir}/uv.tar.gz" -C "${tmp_dir}" && \
    install -m 0755 "${tmp_dir}/uv-x86_64-unknown-linux-gnu/uv" /usr/local/bin/uv && \
    curl -fsSLo "${tmp_dir}/duckdb-cli.zip" "https://github.com/duckdb/duckdb/releases/download/${DUCKDB_VERSION}/duckdb_cli-linux-amd64.zip" && \
    echo "${DUCKDB_SHA256}  ${tmp_dir}/duckdb-cli.zip" | sha256sum --check --status && \
    unzip -q "${tmp_dir}/duckdb-cli.zip" -d "${tmp_dir}/duckdb" && \
    install -m 0755 "${tmp_dir}/duckdb/duckdb" /usr/local/bin/duckdb && \
    curl -fsSLo "${tmp_dir}/action-server" "https://cdn.sema4.ai/action-server/releases/${ACTION_SERVER_VERSION}/linux64/action-server" && \
    echo "${ACTION_SERVER_SHA256}  ${tmp_dir}/action-server" | sha256sum --check --status && \
    install -m 0755 "${tmp_dir}/action-server" /usr/local/bin/action-server && \
    curl -fsSLo "${tmp_dir}/rcc" "https://github.com/joshyorko/rcc/releases/download/${RCC_VERSION}/rcc-linux64" && \
    echo "${RCC_SHA256}  ${tmp_dir}/rcc" | sha256sum --check --status && \
    install -m 0755 "${tmp_dir}/rcc" /usr/local/bin/rcc && \
    rm -rf "${tmp_dir}"

FROM cloud-tools AS dev_containers_target_stage

RUN mkdir -p /home/vscode/.oh-my-zsh/custom/plugins && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions /home/vscode/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting /home/vscode/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting && \
    chown -R vscode:vscode /home/vscode/.oh-my-zsh/custom/plugins

# Create uv cache directory with correct ownership
RUN mkdir -p /home/vscode/.cache/uv && \
    chown -R vscode:vscode /home/vscode/.cache



RUN mkdir -p /usr/local/etc/vscode-dev-containers/ && \
    mv -f /tmp/scripts/first-run-notice.txt /usr/local/etc/vscode-dev-containers/

CMD ["sleep", "infinity"]
