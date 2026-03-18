#!/bin/sh
set -e
set -x

echo "========================================"
echo " Installing Docker & 3CX SBC Container  "
echo "========================================"

# 1. Install Docker on Host
if ! command -v docker > /dev/null; then
    echo "Docker not found. Installing..."
    if [ -f /etc/alpine-release ]; then
        apk add docker
        rc-update add docker boot
        service docker start || true
    else
        apt-get update
        apt-get install -y docker.io
        systemctl enable --now docker
    fi
else
    echo "Docker already installed."
    if [ -f /etc/alpine-release ]; then
        service docker start || true
    else
        systemctl start docker || true
    fi
fi

# 2. Build 3CX SBC Debian 12 Image
echo "Building Debian 12 Docker Image for 3CX SBC..."
mkdir -p /tmp/3cx_sbc_docker
cat << 'EOF' > /tmp/3cx_sbc_docker/Dockerfile
FROM debian:12

# Prevent interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Update System and Install Dependencies
RUN apt-get update && apt-get install -y systemd systemd-sysv sudo wget gnupg gnupg2 dphys-swapfile procps dialog

# Add 3CX Repository and PGP Key
RUN wget -O- https://repo.3cx.com/key.pub | gpg --dearmor | sudo tee /usr/share/keyrings/3cx-archive-keyring.gpg > /dev/null
RUN echo "deb [arch=amd64 by-hash=yes signed-by=/usr/share/keyrings/3cx-archive-keyring.gpg] http://repo.3cx.com/3cx bookworm main" | sudo tee /etc/apt/sources.list.d/3cxpbx.list

# Update Repositories
RUN apt-get update -y && apt-get upgrade -y --with-new-pkgs && apt-get dist-upgrade -y && apt-get autoremove -y

# Install 3CX SBC
RUN apt-get install 3cxsbc -y

# Use systemd as the entrypoint so systemctl commands work correctly inside the container
CMD ["/lib/systemd/systemd"]
EOF

docker build -t debian12-3cxsbc /tmp/3cx_sbc_docker

# 3. Create and Start the Container
echo "Starting 3CX SBC Container (set to auto-restart on boot)..."
docker rm -f 3cx-sbc >/dev/null 2>&1 || true

docker run -d \
  --name 3cx-sbc \
  --privileged \
  --restart always \
  --network host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  debian12-3cxsbc

set +x
echo "=================================================================="
echo " ✅ 3CX SBC Container is now RUNNING!                             "
echo "                                                                  "
echo " You can enter it and work inside Debian 12 at any time via:      "
echo "   docker exec -it 3cx-sbc bash                                   "
echo "                                                                  "
echo " (Inside the container) Check the status:                         "
echo "   sudo systemctl status 3cxsbc                                   "
echo "                                                                  "
echo " (Inside the container) Provide your SBC Provision URL & Key:     "
echo "   dpkg-reconfigure 3cxsbc                                        "
echo "=================================================================="