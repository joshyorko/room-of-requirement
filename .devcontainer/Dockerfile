FROM mcr.microsoft.com/devcontainers/base:noble

# Copy first run notice
COPY first-run-notice.txt /tmp/scripts/

# Add setup script
COPY setup-dev-container.sh /tmp/scripts/setup-dev-container.sh
RUN chmod +x /tmp/scripts/setup-dev-container.sh && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
  build-essential \
  gcc \
  g++ \
  make \
  libc6 \
  libstdc++6 \
  bash \
  git \
  curl \
  wget \
  vim \
  nano \
  zip \
  unzip \
  xclip && \
  /tmp/scripts/setup-dev-container.sh && \
  rm -rf /var/lib/apt/lists/*

# Move first run notice
RUN sudo mkdir -p "/usr/local/etc/vscode-dev-containers/" && \
  sudo mv -f /tmp/scripts/first-run-notice.txt /usr/local/etc/vscode-dev-containers/

CMD ["sleep", "infinity"]
