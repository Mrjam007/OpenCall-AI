#!/bin/bash
set -e

echo "Starting OpenCall AI Installation (Ubuntu LXC)..."

# Step 1: Install Asterisk & Dependencies
echo "Installing Asterisk and core dependencies..."
apt-get update
apt-get install -y asterisk asterisk-dev python3 python3-pip python3-venv \
    zstd curl wget git build-essential

# Copy configs
cp ../asterisk/*.conf /etc/asterisk/
systemctl restart asterisk

# Step 2: Install Ollama (CPU-only enforced for Proxmox LXC)
echo "Installing Ollama..."
# We download the binary directly to prevent the install.sh from crashing
# while trying to install Proxmox (pve) kernel headers for NVIDIA DKMS
curl -L https://ollama.com/download/ollama-linux-amd64.tgz -o ollama-linux-amd64.tgz
tar -C /usr/local -xzf ollama-linux-amd64.tgz
rm ollama-linux-amd64.tgz

# Start Ollama service in the background (required to pull models)
echo "Starting Ollama service..."
useradd -r -s /bin/false -m -d /usr/share/ollama ollama || true
# For testing directly in the script, we can run it in the background
sudo -u ollama ollama serve > /dev/null 2>&1 &
sleep 5 # Wait for daemon to start

# We'll pull the TinyLlama model (you should use GGUF in production)
ollama pull tinyllama

# Step 3: Install Piper TTS
echo "Installing Piper..."
wget https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_linux_x86_64.tar.gz
tar -xf piper_linux_x86_64.tar.gz
mv piper /opt/

# Step 4: Setup Python Environment
echo "Setting up Python Environment..."
cd ../ai_service
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

echo "Installation complete."
echo "Run Asterisk: asterisk -rvvv"
echo "Run Python Service: source venv/bin/activate && python main.py"
