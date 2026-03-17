#!/bin/sh
set -e

# Detect OS
if [ -f /etc/alpine-release ]; then
    OS="alpine"
else
    OS="ubuntu"
fi

echo "Starting OpenCall AI Installation ($OS LXC)..."

# Step 1: Install Asterisk & Dependencies
if ! command -v asterisk > /dev/null; then
    echo "Installing Asterisk and core dependencies..."
    if [ "$OS" = "alpine" ]; then
        apk update
        # Install gcompat and libstdc++ so precompiled glibc binaries (Piper) can run
        apk add asterisk asterisk-dev asterisk-sounds-en python3 py3-pip zstd curl wget git build-base gcompat libstdc++ sudo bash coreutils ollama
    else
        apt-get update
        apt-get install -y asterisk asterisk-dev python3 python3-pip python3-venv \
            zstd curl wget git build-essential sudo
    fi
else
    echo "Asterisk is already installed. Skipping package installation..."
fi

# Create base asterisk config if missing (Alpine sometimes doesn't bundle the default cleanly)
mkdir -p /etc/asterisk
if [ ! -f /etc/asterisk/asterisk.conf ]; then
    echo "[options]" > /etc/asterisk/asterisk.conf
    echo "runuser = asterisk" >> /etc/asterisk/asterisk.conf
    echo "rungroup = asterisk" >> /etc/asterisk/asterisk.conf
fi

if [ ! -f /etc/asterisk/modules.conf ]; then
    echo "[modules]" > /etc/asterisk/modules.conf
    echo "autoload=yes" >> /etc/asterisk/modules.conf
fi

# Copy configs
cp ../asterisk/*.conf /etc/asterisk/
chown -R asterisk:asterisk /etc/asterisk/

if [ "$OS" = "alpine" ]; then
    # Ensure run directory exists for Asterisk PID
    mkdir -p /var/run/asterisk
    chown asterisk:asterisk /var/run/asterisk
    
    # In Alpine, OpenRC is used instead of systemd
    if rc-service asterisk status >/dev/null 2>&1; then
        rc-service asterisk reload || true
    else
        echo "Starting asterisk..."
        rc-service asterisk start || (asterisk -c -vvvvv; false)
    fi
else
    systemctl reload asterisk || systemctl restart asterisk
fi

# Step 2: Install Ollama (CPU-only enforced for Proxmox LXC)
if [ "$OS" = "alpine" ] && [ -f "/usr/local/bin/ollama" ]; then
    echo "Removing incompatible glibc Ollama binary..."
    rm -f /usr/local/bin/ollama
fi

if ! command -v ollama > /dev/null; then
    echo "Installing Ollama..."
    # On Ubuntu we download the binary. On Alpine, install via apk.
    if [ "$OS" != "alpine" ]; then
        curl -sL https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64.tar.zst | zstd -d | tar -xf - -C /usr/local
    else
        apk update
        apk add ollama
    fi
else
    echo "Ollama is already installed. Skipping download..."
fi

# Start Ollama service in the background (required to pull models)
if ! id -u ollama >/dev/null 2>&1; then
    echo "Creating ollama user..."
    if [ "$OS" = "alpine" ]; then
        if ! grep -q '^ollama:' /etc/group; then addgroup -S ollama || true; fi
        adduser -S -D -H -h /usr/share/ollama -s /sbin/nologin -G ollama ollama || true
    else
        useradd -r -s /bin/false -m -d /usr/share/ollama ollama || true
    fi
fi
if [ "$OS" = "alpine" ]; then
    if ! grep -q '^ollama:' /etc/group; then addgroup -S ollama || true; fi
fi
mkdir -p /usr/share/ollama
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

# Create the global command so the user can just type `opencall run` from anywhere
echo "Setting up global 'opencall run' command..."
chmod +x ../scripts/opencall-run.sh
ln -sf "$(pwd)/../scripts/opencall-run.sh" /usr/local/bin/opencall-run

echo "Installation complete."
echo "Run Asterisk: asterisk -rvvv"
echo ""
echo "🚀 You can now start the service from ANYWHERE by typing: opencall-run"
