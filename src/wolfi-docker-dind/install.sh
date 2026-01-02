#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Docker-in-Docker feature for Wolfi-based containers
# Uses native Wolfi apk packages instead of Debian/Ubuntu repos
#-------------------------------------------------------------------------------------------------------------
set -e

INSTALL_BUILDX="${INSTALLBUILDX:-"true"}"
INSTALL_COMPOSE="${INSTALLCOMPOSE:-"true"}"
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

echo "Installing Docker-in-Docker for Wolfi..."

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

echo "Configuring for user: ${USERNAME}"

# Verify we're on Wolfi
if [ ! -f /etc/os-release ]; then
    echo "ERROR: Cannot detect OS. This feature is designed for Wolfi."
    exit 1
fi

. /etc/os-release
if [ "${ID}" != "wolfi" ]; then
    echo "WARNING: This feature is designed for Wolfi. Detected: ${ID}"
    echo "Attempting installation anyway..."
fi

# Install Docker packages via Wolfi apk
# Based on official docker:dind requirements from docker-library/docker
echo "Installing Docker packages via apk..."
apk add --no-cache \
    docker \
    docker-cli \
    docker-cli-buildx \
    containerd \
    runc \
    iptables \
    ip6tables \
    pigz \
    e2fsprogs \
    xfsprogs \
    xz \
    openssl \
    shadow \
    util-linux

# Install docker-compose if requested
if [ "${INSTALL_COMPOSE}" = "true" ]; then
    echo "Installing Docker Compose..."
    apk add --no-cache docker-compose || {
        echo "docker-compose package not found, will install via pip..."
        apk add --no-cache python3 py3-pip
        pip3 install --no-cache-dir docker-compose
    }
fi

# Set up docker group
if ! getent group docker > /dev/null 2>&1; then
    echo "Creating docker group..."
    groupadd -r docker
fi

# Add user to docker group
if [ "${USERNAME}" != "root" ]; then
    echo "Adding ${USERNAME} to docker group..."
    usermod -aG docker ${USERNAME}
fi

# Create the docker-init.sh entrypoint script
# Based on official docker:dind from docker-library/docker and moby/moby hack/dind
echo "Creating docker-init.sh entrypoint..."
cat > /usr/local/share/docker-init.sh << 'INITEOF'
#!/bin/sh
#-------------------------------------------------------------------------------------------------------------
# Docker-in-Docker entrypoint for Wolfi containers
# Based on official docker:dind from docker-library/docker and moby/moby hack/dind
# Properly handles cgroup v2, mount propagation, and daemon startup
#-------------------------------------------------------------------------------------------------------------
set -e

# Remove stale PID files from previous runs
find /run /var/run -iname 'docker*.pid' -delete 2>/dev/null || :
find /run /var/run -iname 'container*.pid' -delete 2>/dev/null || :

# Export container variable - required for AppArmor to work in nested containers
# See: https://github.com/moby/moby/commit/de191e86321f7d3136ff42ff75826b8107399497
export container=docker

# Mount securityfs if available (required for AppArmor)
# See: https://github.com/moby/moby/blob/master/hack/dind
if [ -d /sys/kernel/security ] && ! mountpoint -q /sys/kernel/security; then
    mount -t securityfs none /sys/kernel/security || {
        echo >&2 'Could not mount /sys/kernel/security.'
        echo >&2 'AppArmor detection and --privileged mode might break.'
    }
fi

# Mount /tmp if not already mounted
# /tmp must be exec,rw,dev for Docker to work properly
if ! mountpoint -q /tmp; then
    mount -t tmpfs none /tmp || :
fi

# cgroup v2: enable nesting
# This is CRITICAL for Docker-in-Docker to work on modern systems
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    echo "Setting up cgroup v2 nesting..."
    # Move processes from root group to /init group, otherwise writing
    # subtree_control fails with EBUSY.
    mkdir -p /sys/fs/cgroup/init
    # Loop handles race condition where new processes (like docker exec) spawn
    # while we're moving everything to "init"
    retries=0
    while [ $retries -lt 50 ]; do
        # Move all processes to init cgroup
        xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs 2>/dev/null || :
        # Enable controllers
        if sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers \
            > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null; then
            break
        fi
        retries=$((retries + 1))
        sleep 0.1
    done
    echo "cgroup v2 nesting configured."
fi

# CRITICAL: Change mount propagation to shared
# Without this, containers cannot see their mounts properly
# This makes the environment similar to a modern Linux system with systemd
# See: https://github.com/moby/moby/blob/master/hack/dind
mount --make-rshared / 2>/dev/null || echo "Note: Could not set mount propagation to rshared"

# If no arguments, default to sleep infinity
if [ "$#" -eq 0 ]; then
    set -- sleep infinity
fi

# Start Docker daemon in background
echo "Starting Docker daemon..."
dockerd > /tmp/dockerd.log 2>&1 &
DOCKER_PID=$!

# Wait for Docker to be ready (max 60 seconds)
echo "Waiting for Docker daemon to be ready..."
retry_count=0
docker_ok="false"
while [ "${docker_ok}" != "true" ] && [ "${retry_count}" -lt 60 ]; do
    sleep 1
    if docker info > /dev/null 2>&1; then
        docker_ok="true"
    fi
    retry_count=$((retry_count + 1))
done

if [ "${docker_ok}" = "true" ]; then
    echo "Docker daemon is ready."
else
    echo >&2 "ERROR: Docker daemon failed to start within 60 seconds."
    echo >&2 "Docker logs:"
    cat /tmp/dockerd.log >&2 2>/dev/null || :
    exit 1
fi

# Execute the main command
exec "$@"
INITEOF

chmod +x /usr/local/share/docker-init.sh
chown ${USERNAME}:root /usr/local/share/docker-init.sh 2>/dev/null || true

# Verify installation
echo ""
echo "Verifying Docker installation..."
docker --version || echo "WARNING: docker CLI not found in PATH"
if [ "${INSTALL_COMPOSE}" = "true" ]; then
    docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo "WARNING: docker-compose not found"
fi

echo ""
echo "Docker-in-Docker for Wolfi installation complete!"
echo ""
echo "Note: The Docker daemon will start automatically via the entrypoint."
echo "Make sure your devcontainer runs in privileged mode."
