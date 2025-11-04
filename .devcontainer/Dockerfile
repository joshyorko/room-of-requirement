FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04 AS base

# Copy first run notice
COPY first-run-notice.txt /tmp/scripts/

# System dependencies stage
FROM base AS system-deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    make \
    libc6 \
    libstdc++6 \
    bash \
    git \
    git-lfs \
    curl \
    wget \
    vim \
    sudo \
    postgresql-client \
    nano \
    zip \
    unzip \
    xclip \
    python3.12-venv \
    python3 \
    python3-venv \
    # Browser dependencies
    libnss3 \
    libnspr4 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libx11-6 \
    libpangocairo-1.0-0 \
    libx11-xcb1 \
    libcups2 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libpango-1.0-0 \
    libgbm1 \
    libgtk-3-0 \
    libdbus-1-3 \
    libdrm2 \
    libxcb1 \
    libxext6 \
    libxrandr2 \
    libxshmfence1 \
    libasound2-dev && \
    rm -rf /var/lib/apt/lists/*

# Development tools stage
FROM system-deps AS dev-tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cmake \
    cppcheck \
    valgrind \
    clang \
    lldb \
    llvm \
    gdb \
    python3-dev \
    vim-doc \
    xtail \
    software-properties-common \
    libsecret-1-dev \
    fzf \
    fd-find && \
    rm -rf /var/lib/apt/lists/*

# Cloud tools stage
FROM dev-tools AS cloud-tools
# Set pipefail for RUN commands with pipes
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-mark hold nodejs && \
    npm install -g npm@latest && \
    echo "🚀 Installing Cloud Tools" && \
    # Kind installation
    bash -c '[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64' && \
    chmod +x ./kind && \
    mv ./kind /usr/local/bin/kind && \
    # AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws && \
    # kubectl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends kubectl && \
    # Ansible
    apt-add-repository --yes --update ppa:ansible/ansible && \
    apt-get install -y --no-install-recommends ansible && \
    # Sema4.AI tools
    curl -o action-server https://cdn.sema4.ai/action-server/releases/latest/linux64/action-server && \
    chmod a+x action-server && \
    mv action-server /usr/local/bin/ && \
    curl -L https://github.com/joshyorko/rcc/releases/download/v18.8.0/rcc-linux64 -o /usr/local/bin/rcc && \
    chmod +x /usr/local/bin/rcc && \
    # k3d installation
    curl -L https://github.com/k3d-io/k3d/releases/download/v5.8.3/k3d-linux-amd64 -o /usr/local/bin/k3d && \
    chmod +x /usr/local/bin/k3d && \
    # k9s installation
    curl -L https://github.com/derailed/k9s/releases/download/v0.50.16/k9s_Linux_amd64.tar.gz | tar xz -C /tmp && \
    mv /tmp/k9s /usr/local/bin/k9s && \
    chmod +x /usr/local/bin/k9s && \
    # uv installation
    curl -L https://github.com/astral-sh/uv/releases/download/0.9.7/uv-x86_64-unknown-linux-gnu.tar.gz | tar xz -C /tmp && \
    mv /tmp/uv-x86_64-unknown-linux-gnu/uv /usr/local/bin/uv && \
    chmod +x /usr/local/bin/uv && \
    # DuckDB installation
    curl -L https://github.com/duckdb/duckdb/releases/download/v1.4.1/duckdb_cli-linux-amd64.zip -o /tmp/duckdb.zip && \
    unzip /tmp/duckdb.zip -d /tmp && \
    mv /tmp/duckdb /usr/local/bin/duckdb && \
    chmod +x /usr/local/bin/duckdb && \
    rm -rf /tmp/duckdb.zip /tmp/uv-x86_64-unknown-linux-gnu

# Final stage
FROM cloud-tools AS dev_containers_target_stage
# ZSH setup
RUN mkdir -p /home/vscode/.oh-my-zsh/custom/plugins && \
    git clone https://github.com/zsh-users/zsh-autosuggestions /home/vscode/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting /home/vscode/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting && \
    chown -R vscode:vscode /home/vscode/.oh-my-zsh/custom/plugins && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Move first run notice
RUN mkdir -p "/usr/local/etc/vscode-dev-containers/" && \
    mv -f /tmp/scripts/first-run-notice.txt /usr/local/etc/vscode-dev-containers/

CMD ["sleep", "infinity"]
