#!/bin/sh
set -e

# Resolve the absolute path of the OpenCall-AI directory
# This assumes the script is symlinked to /usr/local/bin or similar
OPENCALL_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
AI_SERVICE_DIR="$OPENCALL_DIR/ai_service"
CONFIG_FILE="$AI_SERVICE_DIR/.env"

if [ ! -d "$AI_SERVICE_DIR/venv" ]; then
    echo "Error: Python virtual environment not found in $AI_SERVICE_DIR."
    echo "Please ensure you have run the install.sh script."
    exit 1
fi

# First Time Setup: 3CX Configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "========================================"
    echo "       OpenCall AI - Initial Setup      "
    echo "========================================"
    echo "Please configure your 3CX details for the Agent."
    
    printf "Enter your 3CX Dashboard URL (e.g., https://mycompany.3cx.us): "
    read THREECX_URL
    
    printf "Enter the Extension Number for the AI agent (e.g., 100): "
    read THREECX_EXT

    printf "\nDo you want to install and run the 3CX SBC locally via Docker? (y/n): "
    read INSTALL_SBC
    if [ "$INSTALL_SBC" = "y" ] || [ "$INSTALL_SBC" = "Y" ]; then
        echo "Setting up 3CX SBC Docker Container..."
        chmod +x "$OPENCALL_DIR/scripts/setup-sbc.sh"
        "$OPENCALL_DIR/scripts/setup-sbc.sh"
    fi

    # Save to .env file
    echo "THREECX_URL=\"$THREECX_URL\"" > "$CONFIG_FILE"
    echo "THREECX_EXT=\"$THREECX_EXT\"" >> "$CONFIG_FILE"
    
    echo "Configuration saved successfully to $CONFIG_FILE!"
    echo "========================================"
fi

echo "Starting OpenCall AI Service..."
cd "$AI_SERVICE_DIR"
. venv/bin/activate

# Automatically export the .env variables so Python can easily use them
export $(grep -v '^#' "$CONFIG_FILE" | xargs)

python3 main.py
