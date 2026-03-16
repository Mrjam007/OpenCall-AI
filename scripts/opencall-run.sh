#!/bin/bash
set -e

# Resolve the absolute path of the OpenCall-AI directory
# This assumes the script is symlinked to /usr/local/bin or similar
OPENCALL_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
AI_SERVICE_DIR="$OPENCALL_DIR/ai_service"

if [ ! -d "$AI_SERVICE_DIR/venv" ]; then
    echo "Error: Python virtual environment not found in $AI_SERVICE_DIR."
    echo "Please ensure you have run the install.sh script."
    exit 1
fi

echo "Starting OpenCall AI Service..."
cd "$AI_SERVICE_DIR"
source venv/bin/activate
python main.py
