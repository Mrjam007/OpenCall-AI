#!/bin/bash
set -e

echo "Starting OpenCall AI Installation (Ubuntu LXC)..."

# Step 1: Install Asterisk
echo "Installing Asterisk..."
apt-get update
apt-get install -y asterisk asterisk-dev python3 python3-pip python3-venv

# Copy configs
cp ../asterisk/*.conf /etc/asterisk/
systemctl restart asterisk

# Step 2: Install Ollama
echo "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh
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
