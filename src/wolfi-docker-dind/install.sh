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
echo "Installing Docker packages via apk..."
apk add --no-cache \
    docker \
    docker-cli \
    docker-cli-buildx \
    containerd \
    runc \
    iptables \
    pigz

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
echo "Creating docker-init.sh entrypoint..."
cat > /usr/local/share/docker-init.sh << 'INITEOF'
#!/bin/sh
#-------------------------------------------------------------------------------------------------------------
# Docker-in-Docker entrypoint for Wolfi containers
# Starts the Docker daemon and handles cgroup setup
#-------------------------------------------------------------------------------------------------------------
set -e

# Remove stale PID files
find /run /var/run -iname 'docker*.pid' -delete 2>/dev/null || :
find /run /var/run -iname 'container*.pid' -delete 2>/dev/null || :

# Export container variable (required for dind)
export container=docker

# Mount securityfs if available
if [ -d /sys/kernel/security ] && ! mountpoint -q /sys/kernel/security; then
    mount -t securityfs none /sys/kernel/security || {
        echo >&2 'Could not mount /sys/kernel/security.'
        echo >&2 'AppArmor detection and --privileged mode might break.'
    }
fi

# Mount /tmp if not already mounted
if ! mountpoint -q /tmp; then
    mount -t tmpfs none /tmp
fi

# Set up cgroup v2 nesting
set_cgroup_nesting() {
    if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
        # Move processes from root group to /init group
        mkdir -p /sys/fs/cgroup/init
        xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs 2>/dev/null || :
        # Enable controllers
        sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers \
            > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || :
    fi
}

# Retry cgroup nesting setup
retry_count=0
until [ "${retry_count}" -eq "5" ]; do
    set_cgroup_nesting
    if [ $? -eq 0 ]; then
        break
    fi
    echo "(*) cgroup v2: Failed to enable nesting, retrying..."
    retry_count=$((retry_count + 1))
    sleep 1
done

# Start containerd first (required by Docker)
echo "Starting containerd..."
containerd > /tmp/containerd.log 2>&1 &

# Wait for containerd to be ready
sleep 2

# Start Docker daemon
echo "Starting Docker daemon..."
dockerd > /tmp/dockerd.log 2>&1 &

# Wait for Docker to be ready
retry_count=0
docker_ok="false"
until [ "${docker_ok}" = "true" ] || [ "${retry_count}" -eq "30" ]; do
    sleep 1
    if docker info > /dev/null 2>&1; then
        docker_ok="true"
        echo "Docker daemon is ready."
    fi
    retry_count=$((retry_count + 1))
done

if [ "${docker_ok}" != "true" ]; then
    echo "WARNING: Docker daemon may not have started correctly."
    echo "Check /tmp/dockerd.log for details."
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
