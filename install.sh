#!/bin/bash
# Barcode Scanner Installation Script for Raspberry Pi
# This script installs all dependencies and sets up the barcode scanner service

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if running as root for system packages
if [[ $EUID -eq 0 ]]; then
    warn "This script should be run as the pi user, not root"
    warn "Some operations will use sudo when needed"
fi

# Project directory
PROJECT_DIR="/home/pi/barcode-scanner"

log "Starting Barcode Scanner installation..."

# Update system packages
log "Updating system packages..."
sudo apt-get update

# Install system dependencies
log "Installing system dependencies..."
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    kbd \
    git \
    curl \
    build-essential \
    python3-dev \
    libffi-dev \
    libssl-dev

# Create project directory if it doesn't exist
log "Setting up project directory..."
if [ ! -d "$PROJECT_DIR" ]; then
    sudo mkdir -p "$PROJECT_DIR"
fi

# Ensure pi user owns the project directory
sudo chown -R pi:pi "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create necessary directories
log "Creating project directories..."
mkdir -p data
mkdir -p logs
mkdir -p scripts

# Create and activate virtual environment
log "Creating Python virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
log "Upgrading pip..."
pip install --upgrade pip

# Install Python dependencies
log "Installing Python dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    error "requirements.txt not found! Make sure all project files are in $PROJECT_DIR"
    exit 1
fi

# Create example configuration files if they don't exist
log "Setting up configuration files..."

# Create .env.example if it doesn't exist
if [ ! -f ".env.example" ]; then
    cat > .env.example << 'EOF'
# Device identification
DEVICE_ID=pi_scanner_01
DEVICE_LOCATION=Main Location

# Paths
BASE_DIR=/home/pi/barcode-scanner/data
BOX_CONFIG_PATH=/home/pi/barcode-scanner/box_config.json

# Box settings (get these from Box Developer Console)
TARGET_FOLDER_ID=your_box_folder_id_here
COLLABORATOR_EMAIL=manager@company.com

# Scanner settings
BARCODE_TIMEOUT=5
MAX_RETRIES=3
RETRY_DELAY=5
LOG_LEVEL=INFO
EOF
fi

# Create box_config.example.json if it doesn't exist
if [ ! -f "box_config.example.json" ]; then
    cat > box_config.example.json << 'EOF'
{
  "boxAppSettings": {
    "clientID": "your_client_id_here",
    "clientSecret": "your_client_secret_here",
    "appAuth": {
      "publicKeyID": "your_public_key_id_here",
      "privateKey": "-----BEGIN ENCRYPTED PRIVATE KEY-----\nyour_private_key_here\n-----END ENCRYPTED PRIVATE KEY-----",
      "passphrase": "your_passphrase_here"
    }
  },
  "enterpriseID": "your_enterprise_id_here"
}
EOF
fi

# Copy example files to actual config files if they don't exist
if [ ! -f ".env" ]; then
    cp .env.example .env
    warn "Created .env file from example. Please edit it with your actual configuration!"
fi

if [ ! -f "box_config.json" ]; then
    cp box_config.example.json box_config.json
    warn "Created box_config.json from example. Please edit it with your actual Box JWT credentials!"
fi

# Set proper permissions
log "Setting file permissions..."
chmod 755 "$PROJECT_DIR"
chmod 755 "$PROJECT_DIR/data"
chmod 755 "$PROJECT_DIR/logs"
chmod 644 "$PROJECT_DIR"/*.py
chmod 600 "$PROJECT_DIR/.env"
chmod 600 "$PROJECT_DIR/box_config.json"

# Install systemd service
log "Installing systemd service..."
if [ -f "scripts/barcode-scanner.service" ]; then
    sudo cp scripts/barcode-scanner.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable barcode-scanner
    log "Systemd service installed and enabled"
else
    error "Service file not found at scripts/barcode-scanner.service"
    exit 1
fi

# Create startup test script
log "Creating test script..."
cat > scripts/test_scanner.py << 'EOF'
#!/usr/bin/env python3
"""
Test script to verify barcode scanner installation
"""
import sys
import os
sys.path.append('/home/pi/barcode-scanner')

try:
    from barcode_scanner import Config
    print("✓ Configuration module loaded successfully")
    
    config = Config()
    print("✓ Configuration validated successfully")
    print(f"✓ Base directory: {config.base_dir}")
    print(f"✓ Box config path: {config.box_config_path}")
    
    # Test imports
    import openpyxl
    print("✓ openpyxl imported successfully")
    
    import keyboard
    print("✓ keyboard imported successfully")
    
    from boxsdk import JWTAuth, Client
    print("✓ Box SDK imported successfully")
    
    print("\n🎉 Installation test completed successfully!")
    print("Next steps:")
    print("1. Edit .env file with your configuration")
    print("2. Edit box_config.json with your Box JWT credentials") 
    print("3. Start the service: sudo systemctl start barcode-scanner")
    
except Exception as e:
    print(f"❌ Installation test failed: {e}")
    sys.exit(1)
EOF

chmod +x scripts/test_scanner.py

# Create monitoring script
log "Creating monitoring script..."
cat > scripts/monitor.sh << 'EOF'
#!/bin/bash
# Quick monitoring script for barcode scanner

echo "=== Barcode Scanner Status ==="
echo "Service Status:"
systemctl is-active barcode-scanner || echo "Service is not running"

echo -e "\nLast 10 log entries:"
sudo journalctl -u barcode-scanner -n 10 --no-pager

echo -e "\nDisk usage for data directory:"
du -sh /home/pi/barcode-scanner/data

echo -e "\nRecent files in data directory:"
ls -la /home/pi/barcode-scanner/data | tail -5
EOF

chmod +x scripts/monitor.sh

log "Installation completed successfully!"
echo
info "Next steps:"
info "1. Edit configuration files:"
info "   nano $PROJECT_DIR/.env"
info "   nano $PROJECT_DIR/box_config.json"
echo
info "2. Test the installation:"
info "   cd $PROJECT_DIR && python3 scripts/test_scanner.py"
echo
info "3. Start the service:"
info "   sudo systemctl start barcode-scanner"
echo
info "4. Monitor the service:"
info "   sudo systemctl status barcode-scanner"
info "   ./scripts/monitor.sh"
echo
warn "IMPORTANT: Make sure to configure your .env and box_config.json files before starting!"
