#!/bin/bash

# Function to show step progress
show_progress() {
    echo "⌛ $1..."
}

# Function to show success
show_success() {
    echo "✅ $1"
}

# Function to handle errors
handle_error() {
    echo "❌ Error: $1"
    exit 1
}

echo "🚀 Starting development container setup..."



show_progress "Installing AWS CLI v2"
{
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" >/dev/null 2>&1 &&
    unzip awscliv2.zip >/dev/null 2>&1 &&
    sudo ./aws/install >/dev/null 2>&1 &&
    rm -rf awscliv2.zip aws
} || handle_error "Failed to install AWS CLI v2"
show_success "AWS CLI v2 installed"



show_progress "Installing essential packages"
{
    sudo apt install -y --no-install-recommends \
        git git-lfs curl vim sudo postgresql-client \
        build-essential cmake cppcheck valgrind clang lldb llvm \
        gdb python3-dev vim-doc xtail software-properties-common \
        libsecret-1-dev libnss3 libnspr4 libatk-bridge2.0-0 \
        libatk1.0-0 libx11-6 libpangocairo-1.0-0 libx11-xcb1 \
        libcups2 libxcomposite1 libxdamage1 libxfixes3 \
        libpango-1.0-0 libgbm1 libgtk-3-0 >/dev/null 2>&1
} || handle_error "Failed to install essential packages"
show_success "Essential packages installed"


show_progress "Installing kubectl"
{
    # Download and add Google Cloud public signing key
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg &&
    # Add Kubernetes apt repository
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list &&
    # Update apt package index
    sudo apt-get update >/dev/null 2>&1 &&
    # Install kubectl
    sudo apt-get install -y kubectl >/dev/null 2>&1
} || {
    echo "Attempting alternative kubectl installation method..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" &&
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl &&
    rm kubectl
} || handle_error "Failed to install kubectl"
show_success "kubectl installed"

show_progress "Installing Ansible"
{
    sudo apt-add-repository --yes --update ppa:ansible/ansible >/dev/null 2>&1 &&
    sudo apt install -y ansible >/dev/null 2>&1
} || handle_error "Failed to install Ansible"
show_success "Ansible installed"

show_progress "Cleaning up apt cache"
{
    sudo apt clean >/dev/null 2>&1 &&
    sudo rm -rf /var/lib/apt/lists/* >/dev/null 2>&1
} || true
show_success "Cleanup completed"

show_progress "Installing MinIO client"
{
    curl -s -O https://dl.min.io/client/mc/release/linux-amd64/mc &&
    chmod +x mc &&
    sudo mv mc /usr/local/bin/
} || handle_error "Failed to install MinIO client"
show_success "MinIO client installed"


show_progress "Installing fzf and fd-find"
{
    sudo apt update >/dev/null 2>&1 &&
    sudo apt install -y fzf fd-find >/dev/null 2>&1
} || handle_error "Failed to install fzf and fd-find"
show_success "fzf and fd-find installed"

show_progress "Setting up Git LFS"
{
    git lfs install >/dev/null 2>&1
} || handle_error "Failed to setup Git LFS"
show_success "Git LFS configured"

show_progress "Setting up ZSH configuration"
{
    curl -fsSL https://raw.githubusercontent.com/joshyorko/.dotfiles/refs/heads/main/dotfiles/.zshrc -o /home/vscode/.zshrc &&
    curl -fsSL https://raw.githubusercontent.com/joshyorko/.dotfiles/refs/heads/main/scripts/scrapeCrawl.py -o /home/vscode/scrapeCrawl.py &&
    sudo chown vscode:vscode /home/vscode/.zshrc &&
    sudo chown vscode:vscode /home/vscode/scrapeCrawl.py &&
    git clone https://github.com/zsh-users/zsh-autosuggestions /home/vscode/.oh-my-zsh/custom/plugins/zsh-autosuggestions >/dev/null 2>&1 &&
    git clone https://github.com/zsh-users/zsh-syntax-highlighting /home/vscode/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting >/dev/null 2>&1 &&
    sudo chown -R vscode:vscode /home/vscode/.oh-my-zsh/custom/plugins
} || handle_error "Failed to setup ZSH configuration"
show_success "ZSH configuration completed"