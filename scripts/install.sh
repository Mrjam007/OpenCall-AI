#!/bin/bash
set -e

echo "Starting OpenCall AI Installation (Ubuntu LXC)..."

# Step 1: Install Asterisk & Dependencies
if ! command -v asterisk > /dev/null; then
    echo "Installing Asterisk and core dependencies..."
    apt-get update
    apt-get install -y asterisk asterisk-dev python3 python3-pip python3-venv \
        zstd curl wget git build-essential
else
    echo "Asterisk is already installed. Skipping apt-get..."
fi

# Copy configs
cp ../asterisk/*.conf /etc/asterisk/
systemctl reload asterisk || systemctl restart asterisk

# Step 2: Install Ollama (CPU-only enforced for Proxmox LXC)
if ! command -v ollama > /dev/null && [ ! -f "/usr/local/bin/ollama" ]; then
    echo "Installing Ollama..."
    # We download the binary directly to prevent the install.sh from crashing
    # while trying to install Proxmox (pve) kernel headers for NVIDIA DKMS
    curl -sL https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64.tar.zst | zstd -d | tar -xf - -C /usr/local
else
    echo "Ollama is already installed. Skipping download..."
fi

# Start Ollama service in the background (required to pull models)
if ! id -u ollama > /dev/null 2>&1; then
    echo "Creating ollama user..."
    useradd -r -s /bin/false -m -d /usr/share/ollama ollama || true
fi
# Ensure ownership
chown -R ollama:ollama /usr/share/ollama

# Check if Ollama endpoint is responding; if not, start it
if ! curl -s http://127.0.0.1:11434/ > /dev/null; then
    echo "Starting Ollama service..."
    # For testing directly in the script, we can run it in the background
    sudo -u ollama OLLAMA_HOST=127.0.0.1:11434 ollama serve > /dev/null 2>&1 &
    sleep 5 # Wait for daemon to start
else
    echo "Ollama service is already running..."
fi

if ! sudo -u ollama OLLAMA_HOST=127.0.0.1:11434 ollama list | grep -q "tinyllama"; then
    echo "Pulling TinyLlama model..."
    # We'll pull the TinyLlama model (you should use GGUF in production)
    OLLAMA_HOST=127.0.0.1:11434 ollama pull tinyllama
else
    echo "TinyLlama model already pulled..."
fi

# Step 3: Install Piper TTS
if [ ! -f "/opt/piper/piper" ]; then
    echo "Installing Piper..."
    wget https://github.com/rhasspy/piper/releases/latest/download/piper_linux_x86_64.tar.gz
    tar -xf piper_linux_x86_64.tar.gz
    mv piper /opt/
    rm piper_linux_x86_64.tar.gz
else
    echo "Piper is already installed. Skipping download..."
fi

# Step 4: Setup Python Environment
echo "Setting up Python Environment..."
cd ../ai_service
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
else
    echo "Python virtual environment already exists..."
fi

source venv/bin/activate
echo "Verifying Python dependencies..."
pip install -r requirements.txt

echo "Installation complete."
echo "Run Asterisk: asterisk -rvvv"
echo "Run Python Service: source venv/bin/activate && python main.py"
