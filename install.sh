#!/bin/bash
# Barcode Scanner Installation Script for Raspberry Pi
# This script installs all dependencies and sets up the barcode scanner service for CLI mode

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

log "Starting Barcode Scanner installation for CLI mode..."

# Update system packages
log "Updating system packages..."
sudo apt-get update

# Install system dependencies (including CLI input support)
log "Installing system dependencies and CLI input support..."
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
    libssl-dev \
    libinput-tools \
    input-utils \
    console-data \
    xserver-xorg-input-evdev

# Install keyboard library system-wide for CLI mode
log "Installing keyboard library system-wide for CLI compatibility..."
sudo pip install keyboard --break-system-packages

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
    # Also install keyboard in venv for consistency
    pip install keyboard
else
    error "requirements.txt not found! Make sure all project files are in $PROJECT_DIR"
    exit 1
fi

# Setup CLI input support
log "Configuring CLI input support..."

# Add required kernel modules for CLI mode
echo 'uinput' | sudo tee -a /etc/modules >/dev/null
echo 'evdev' | sudo tee -a /etc/modules >/dev/null

# Create udev rule for barcode scanners
sudo tee /etc/udev/rules.d/99-barcode-scanner.rules << 'EOF'
# Barcode scanner input device rules for CLI mode
SUBSYSTEM=="input", ATTRS{idVendor}=="2f50", ATTRS{idProduct}=="0301", MODE="0666", GROUP="input", TAG+="uaccess"
KERNEL=="event*", SUBSYSTEM=="input", MODE="0666", GROUP="input"
# Generic HID keyboard devices (for various barcode scanners)
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{bInterfaceClass}=="03", ATTRS{bInterfaceSubClass}=="01", ATTRS{bInterfaceProtocol}=="01", MODE="0666", GROUP="input"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Create configuration files with prompts
log "Setting up configuration files..."

# Create .env file with user input
if [ ! -f ".env" ]; then
    log "Creating .env configuration file..."
    
    # Get device identification
    echo
    info "Device Configuration:"
    read -p "Enter Device ID (e.g., pi_warehouse_01): " DEVICE_ID
    read -p "Enter Device Location (e.g., Main Warehouse): " DEVICE_LOCATION
    
    # Get Box settings
    echo
    info "Box Configuration:"
    read -p "Enter Target Folder ID from Box: " TARGET_FOLDER_ID
    read -p "Enter Collaborator Email: " COLLABORATOR_EMAIL
    
    # Create .env file
    cat > .env << EOF
# Device identification (make unique for each Pi)
DEVICE_ID=${DEVICE_ID:-pi_scanner_01}
DEVICE_LOCATION=${DEVICE_LOCATION:-Default Location}

# Paths (usually don't need to change)
BASE_DIR=/home/pi/barcode-scanner/data
BOX_CONFIG_PATH=/home/pi/barcode-scanner/box_config.json

# Box settings (get these from Box Developer Console)
TARGET_FOLDER_ID=${TARGET_FOLDER_ID:-your_box_folder_id_here}
COLLABORATOR_EMAIL=${COLLABORATOR_EMAIL:-manager@company.com}

# Scanner settings
BARCODE_TIMEOUT=5          # Seconds to wait for complete barcode
MAX_RETRIES=3             # Box upload retry attempts
RETRY_DELAY=5             # Seconds between retries
LOG_LEVEL=INFO            # DEBUG, INFO, WARNING, ERROR
EOF
    
    log "Created .env file with your configuration"
else
    warn ".env file already exists, skipping creation"
fi

# Create box_config.json template
if [ ! -f "box_config.json" ]; then
    log "Creating Box configuration template..."
    
    echo
    warn "You need to download your JWT configuration from Box Developer Console"
    warn "Visit: https://app.box.com/developers/console"
    echo
    info "Creating template box_config.json file..."
    
    cat > box_config.json << 'EOF'
{
  "boxAppSettings": {
    "clientID": "YOUR_CLIENT_ID_HERE",
    "clientSecret": "YOUR_CLIENT_SECRET_HERE",
    "appAuth": {
      "publicKeyID": "YOUR_PUBLIC_KEY_ID_HERE",
      "privateKey": "-----BEGIN ENCRYPTED PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END ENCRYPTED PRIVATE KEY-----",
      "passphrase": "YOUR_PASSPHRASE_HERE"
    }
  },
  "enterpriseID": "YOUR_ENTERPRISE_ID_HERE"
}
EOF
    
    warn "IMPORTANT: Replace box_config.json with your actual JWT configuration from Box!"
    warn "Or rename your downloaded config file: mv your_downloaded_*_config.json box_config.json"
else
    log "box_config.json already exists"
fi

# Set executable permissions for scripts (use repo versions if available)
log "Setting script permissions..."
if [ -f "scripts/test_scanner.py" ]; then
    chmod +x scripts/test_scanner.py
    log "Test script found in repo and permissions set"
else
    warn "Test script not found in repo, creating basic fallback version..."
    cat > scripts/test_scanner.py << 'EOF'
#!/usr/bin/env python3
"""
Test script to verify barcode scanner installation
"""
import sys
import os
sys.path.append('/home/pi/barcode-scanner')

try:
    print("Testing barcode scanner installation...")
    
    # Test basic imports
    import openpyxl
    print("✓ openpyxl imported successfully")
    
    import keyboard
    print("✓ keyboard imported successfully")
    
    from boxsdk import JWTAuth, Client
    print("✓ Box SDK imported successfully")
    
    # Test configuration loading
    from dotenv import load_dotenv
    load_dotenv()
    
    import os
    device_id = os.getenv("DEVICE_ID", "not_set")
    target_folder = os.getenv("TARGET_FOLDER_ID", "not_set")
    
    print(f"✓ Device ID: {device_id}")
    print(f"✓ Target Folder ID: {target_folder}")
    
    print("\n🎉 Installation test completed successfully!")
    print("Next steps:")
    print("1. Configure box_config.json with your Box JWT credentials")
    print("2. Update .env file if needed")
    print("3. Start the service: sudo systemctl start barcode-scanner")
    
except Exception as e:
    print(f"❌ Installation test failed: {e}")
    sys.exit(1)
EOF
    chmod +x scripts/test_scanner.py
fi

if [ -f "scripts/monitor.sh" ]; then
    chmod +x scripts/monitor.sh
    log "Monitor script found in repo and permissions set"
else
    warn "Monitor script not found in repo, creating basic fallback version..."
    cat > scripts/monitor.sh << 'EOF'
#!/bin/bash
# Monitoring script for barcode scanner

echo "=== Barcode Scanner Status ==="
echo "Service Status:"
systemctl is-active barcode-scanner || echo "Service is not running"

echo -e "\nService Details:"
sudo systemctl status barcode-scanner --no-pager --lines=5

echo -e "\nLast 5 log entries:"
sudo journalctl -u barcode-scanner -n 5 --no-pager

echo -e "\nDisk usage for data directory:"
du -sh /home/pi/barcode-scanner/data 2>/dev/null || echo "Data directory not found"

echo -e "\nRecent files in data directory:"
ls -la /home/pi/barcode-scanner/data 2>/dev/null | tail -3 || echo "No files found"

echo -e "\nInput devices:"
ls -la /dev/input/ | grep event
EOF
    chmod +x scripts/monitor.sh
fi

# Set proper permissions
log "Setting file permissions..."
chmod 755 "$PROJECT_DIR"
chmod 755 "$PROJECT_DIR/data"
chmod 755 "$PROJECT_DIR/logs"
chmod 644 "$PROJECT_DIR"/*.py 2>/dev/null || true
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
    # Create service file if not found in repo
    warn "Service file not found in repo, creating from template..."
    sudo tee /etc/systemd/system/barcode-scanner.service << 'EOF'
[Unit]
Description=Barcode Scanner Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/home/pi/barcode-scanner
Environment="PATH=/home/pi/barcode-scanner/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/home/pi/barcode-scanner/venv/bin/python /home/pi/barcode-scanner/barcode_scanner.py

# Restart configuration
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=5

# Logging
StandardOutput=journal
StandardError=journal

# Security options
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable barcode-scanner
    log "Systemd service created and enabled"
fi

# Set CLI mode as default
log "Configuring system for CLI mode..."
sudo systemctl set-default multi-user.target

log "Installation completed successfully!"
echo
info "🎉 Barcode Scanner Installation Complete!"
echo
info "Next steps:"
info "1. Configure Box JWT credentials:"
info "   - Download JWT config from: https://app.box.com/developers/console"
info "   - Replace box_config.json with your downloaded file"
info "   - Or rename: mv your_downloaded_*_config.json box_config.json"
echo
info "2. Verify configuration:"
info "   python3 scripts/test_scanner.py"
echo
info "3. Reboot to CLI mode:"
info "   sudo reboot"
echo
info "4. After reboot, start the service:"
info "   sudo systemctl start barcode-scanner"
echo
info "5. Monitor the service:"
info "   sudo systemctl status barcode-scanner"
info "   ./scripts/monitor.sh"
echo
warn "⚠️  IMPORTANT:"
warn "- System will reboot to CLI mode (no desktop)"
warn "- Configure box_config.json before starting the service"
warn "- Use SSH for remote management: ssh pi@$(hostname -I | cut -d' ' -f1)"
echo
info "📋 Quick Reference:"
info "- View logs: sudo journalctl -u barcode-scanner -f"
info "- Restart service: sudo systemctl restart barcode-scanner"
info "- Return to desktop: sudo systemctl set-default graphical.target && sudo reboot"
