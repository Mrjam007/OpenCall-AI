#!/bin/bash
set -e

echo "Starting OpenCall AI update..."

# 1. Pull latest code
echo "Pulling latest changes from Git..."
# Stash any local changes to scripts or configs to avoid overwrite errors
git stash
git pull
git stash pop || echo "No local changes to pop, or minor conflict resolved automatically."

# 2. Update Asterisk configurations
echo "Updating Asterisk configurations..."
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cp "$SCRIPT_DIR/../asterisk/"*.conf /etc/asterisk/
systemctl reload asterisk || systemctl restart asterisk

# 3. Update Python dependencies
echo "Updating Python environment..."
cd "$SCRIPT_DIR/../ai_service"
if [ -d "venv" ]; then
    source venv/bin/activate
    pip install -r requirements.txt
else
    echo "Virtual environment not found in ai_service. Please run install.sh first."
fi

# 4. Optional: Add steps to update Ollama models if necessary
# echo "Pulling latest Ollama model..."
# OLLAMA_HOST=127.0.0.1:11434 ollama pull tinyllama

echo "==================================="
echo "Update complete!"
echo "If the Python AI service (main.py) is currently running, please restart it to apply the latest changes."
echo "==================================="
