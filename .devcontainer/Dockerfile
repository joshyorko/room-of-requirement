# syntax=docker/dockerfile:1.7

ARG KIND_VERSION=v0.30.0
ARG KIND_SHA256=517ab7fc89ddeed5fa65abf71530d90648d9638ef0c4cde22c2c11f8097b8889
ARG K3D_VERSION=v5.8.3
ARG K3D_SHA256=dbaa79a76ace7f4ca230a1ff41dc7d8a5036a8ad0309e9c54f9bf3836dbe853e
ARG K9S_VERSION=v0.50.16
ARG K9S_SHA256=bda09dc030a08987fe2b3bed678b15b52f23d6705e872d561932d4ca07db7818
ARG UV_VERSION=0.9.11
ARG UV_SHA256=817c0722b437b4b45b9a7e0231616a09db76bab1b8d178ba7a9680c690db19f0
ARG DUCKDB_VERSION=v1.4.2
ARG DUCKDB_SHA256=fae3ba93eedf20b08bca4b23aeac1ba94c446f1c10d029c193e2fc4b4e0bc1bc
ARG RCC_VERSION=v18.9.1
ARG RCC_SHA256=31e08906d6e152d4cd5d20a8af98a04d94d927a8a75e59d820821fd457ec56c9
ARG ACTION_SERVER_VERSION=2.17.0
ARG ACTION_SERVER_SHA256=1a4f2f1d5dec477ebba02e51de42c0aff7319dda04cb75b4fc3ae7e2192192a1
ARG AWSCLI_VERSION=2.32.3
ARG AWSCLI_SHA256=88726b85d0a333ac419ccbd22f3e1fc97b1365e6c81cfb38b676ef82f98b00c5
ARG HAULER_VERSION=1.3.1
ARG HAULER_SHA256=d38bb543feeb7ea5a73a92cbba1e121ee44c001e1214475f6394953b29c10a5d

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
ARG AWSCLI_VERSION
ARG AWSCLI_SHA256
ARG HAULER_VERSION
ARG HAULER_SHA256

# Install Node.js runtime via nvm (more reliable than NodeSource)
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=22
RUN mkdir -p "${NVM_DIR}" && \
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    . "${NVM_DIR}/nvm.sh" && \
    nvm install "${NODE_VERSION}" && \
    nvm alias default "${NODE_VERSION}" && \
    nvm use default && \
    npm install -g npm@latest && \
    ln -sf "${NVM_DIR}/versions/node/$(nvm version default)/bin/node" /usr/local/bin/node && \
    ln -sf "${NVM_DIR}/versions/node/$(nvm version default)/bin/npm" /usr/local/bin/npm && \
    ln -sf "${NVM_DIR}/versions/node/$(nvm version default)/bin/npx" /usr/local/bin/npx

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
    curl -fsSLo "${tmp_dir}/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" && \
    echo "${AWSCLI_SHA256}  ${tmp_dir}/awscliv2.zip" | sha256sum --check --status && \
    unzip -q "${tmp_dir}/awscliv2.zip" -d "${tmp_dir}" && \
    "${tmp_dir}/aws/install" --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli && \
    curl -fsSLo "${tmp_dir}/hauler.tar.gz" "https://github.com/hauler-dev/hauler/releases/download/v${HAULER_VERSION}/hauler_${HAULER_VERSION}_linux_amd64.tar.gz" && \
    echo "${HAULER_SHA256}  ${tmp_dir}/hauler.tar.gz" | sha256sum --check --status && \
    tar -xzf "${tmp_dir}/hauler.tar.gz" -C "${tmp_dir}" hauler && \
    install -m 0755 "${tmp_dir}/hauler" /usr/local/bin/hauler && \
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
