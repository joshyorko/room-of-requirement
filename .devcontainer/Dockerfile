FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Copy first run notice
COPY first-run-notice.txt /tmp/scripts/

# APE STRONK SETUP - ALL IN ONE RUN COMMAND!
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
  && \
  # INSTALL AWS CLI v2 - APE STYLE!
  echo "🚀 APE INSTALLING AWS CLI v2!" && \
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
  unzip awscliv2.zip && \
  ./aws/install && \
  rm -rf awscliv2.zip aws && \
  # INSTALL KUBECTL - GORILLA STRENGTH!
  echo "🚀 APE INSTALLING KUBECTL!" && \
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && \
  apt-get update && \
  apt-get install -y kubectl && \
  # GORILLA INSTALL ANSIBLE!
  echo "🚀 APE INSTALLING ANSIBLE!" && \
  apt-add-repository --yes --update ppa:ansible/ansible && \
  apt-get install -y ansible && \
  # MIGHTY APE INSTALL MINIO CLIENT!
  echo "🚀 APE INSTALLING MINIO CLIENT!" && \
  curl -s -O https://dl.min.io/client/mc/release/linux-amd64/mc && \
  chmod +x mc && \
  mv mc /usr/local/bin/ && \
  # FZF AND FD-FIND FOR BANANA SEARCH!
  echo "🚀 APE INSTALLING FZF AND FD-FIND!" && \
  apt-get install -y fzf fd-find && \
  # GIT LFS SETUP FOR BIG BANANA FILES!
  echo "🚀 APE SETTING UP GIT LFS!" && \
  git lfs install && \
  # DOWNLOAD SEMA4.AI ACTION SERVER - APE TECH!
  echo "🚀 APE INSTALLING SEMA4.AI TOOLS!" && \
  curl -o action-server https://cdn.sema4.ai/action-server/releases/latest/linux64/action-server && \
  chmod a+x action-server && \
  mv action-server /usr/local/bin/ && \
  # DOWNLOAD AND INSTALL RCC
  curl -o rcc https://cdn.sema4.ai/rcc/releases/latest/linux64/rcc && \
  chmod a+x rcc && \
  mv rcc /usr/local/bin/ && \
  # APE CLEAN JUNGLE MESS!
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# SETUP ZSH CONFIG FOR POWERFUL APE TERMINAL!
RUN mkdir -p /home/vscode/.oh-my-zsh/custom/plugins && \
  curl -fsSL https://raw.githubusercontent.com/joshyorko/.dotfiles/refs/heads/main/dotfiles/.zshrc -o /home/vscode/.zshrc && \
  curl -fsSL https://raw.githubusercontent.com/joshyorko/.dotfiles/refs/heads/main/scripts/scrapeCrawl.py -o /home/vscode/scrapeCrawl.py && \
  git clone https://github.com/zsh-users/zsh-autosuggestions /home/vscode/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting /home/vscode/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting && \
  chown -R vscode:vscode /home/vscode/.oh-my-zsh/custom/plugins && \
  chown vscode:vscode /home/vscode/.zshrc && \
  chown vscode:vscode /home/vscode/scrapeCrawl.py

# Move first run notice
RUN mkdir -p "/usr/local/etc/vscode-dev-containers/" && \
  mv -f /tmp/scripts/first-run-notice.txt /usr/local/etc/vscode-dev-containers/

CMD ["sleep", "infinity"]
