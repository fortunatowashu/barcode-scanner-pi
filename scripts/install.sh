#!/bin/bash

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install system dependencies
echo "Installing system dependencies..."
sudo apt-get install -y python3-pip python3-venv git

# Create virtual environment
echo "Creating Python virtual environment..."
cd /home/pi/barcode-scanner
python3 -m venv venv

# Activate virtual environment and install packages
echo "Installing Python packages..."
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Set permissions
echo "Setting permissions..."
sudo chmod +x barcode_scanner.py
sudo chmod +x scripts/install.sh

# Create systemd service
echo "Installing systemd service..."
sudo cp scripts/barcode-scanner.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable barcode-scanner.service

echo "Installation complete!"
echo "To start the service: sudo systemctl start barcode-scanner"
echo "To check status: sudo systemctl status barcode-scanner"
echo "To view logs: sudo journalctl -u barcode-scanner -f"