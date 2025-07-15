Enhanced Barcode Scanner Project for Raspberry Pi
Overview
This project enables a headless Raspberry Pi to capture barcode input from a connected barcode scanner and log the scanned data—with timestamps—into an Excel file. The system features robust error handling, automatic recovery, and seamless Box integration with JWT authentication for secure cloud storage.

Key Improvements in This Version:

Enhanced error handling and retry logic
Systemd service for reliable process management
Comprehensive logging and monitoring
Barcode input validation and timeout handling
Thread-safe operations and non-blocking uploads
Production-ready configuration management


Table of Contents

Features
Requirements
Installation & Setup
Configuration
Box Integration Setup
Running the Project
Production Deployment
Monitoring & Maintenance
Troubleshooting
Project Structure

Features

Robust Barcode Input Capture: Advanced barcode processing with timeout handling and validation
Excel Logging with Status Tracking: Comprehensive logging including SUCCESS, TIMEOUT, INVALID, and RECOVERED statuses
Reliable Box Integration: JWT authentication with retry logic and automatic collaborator management
Production-Ready Error Handling: Graceful failure recovery and detailed logging
Systemd Service Management: Automatic startup, restart, and process monitoring
Thread-Safe Operations: Non-blocking uploads and concurrent file operations
Configuration Validation: Early detection of configuration issues with clear error messages

Requirements
Hardware & OS

Raspberry Pi running Raspberry Pi OS (64-bit recommended)
USB Barcode Scanner (keyboard wedge mode)
Minimum 8GB SD card
Internet connection for Box uploads

Software

Python 3.9 or later
systemd (standard on Raspberry Pi OS)
Required Python libraries (see requirements.txt)

Installation & Setup
1. Prepare the Raspberry Pi
Update your system:
bashsudo apt update && sudo apt upgrade -y
sudo apt install python3-pip python3-venv git -y
2. Clone the Repository
bashgit clone https://github.com/yourusername/barcode-scanner-pi.git
cd barcode-scanner-pi
3. Create Project Structure
bash# Create necessary directories
mkdir -p logs data config

# Set proper permissions
chmod 755 logs data config
4. Set Up Python Virtual Environment
bashpython3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
5. Install Dependencies
bashpip install -r requirements.txt
6. Configure User Permissions
Add your user to the input group for keyboard access:
bashsudo usermod -a -G input $USER
Create udev rule for barcode scanner access:
bashsudo tee /etc/udev/rules.d/99-barcode-scanner.rules << EOF
SUBSYSTEM=="input", GROUP="input", MODE="0664"
KERNEL=="event*", GROUP="input", MODE="0664"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger
Important: Log out and log back in for group changes to take effect.
Configuration
1. Create Environment Configuration
Copy the example environment file:
bashcp .env.example .env
Edit the .env file:
bashnano .env
Configure with your settings:
bash# Required Box Configuration
BOX_CONFIG_PATH=./config/box_config.json
TARGET_FOLDER_ID=your_box_folder_id_here
COLLABORATOR_EMAIL=your_email@example.com

# Application Settings
BASE_DIR=./data
LOG_LEVEL=INFO

# Optional Settings (with defaults)
BARCODE_TIMEOUT=5
MAX_RETRIES=3
RETRY_DELAY=5
2. Test Configuration
Run the configuration test:
bashpython test_box_connection.py
This will validate your Box configuration and provide detailed feedback on any issues.
Box Integration Setup
Step 1: Create Box JWT Application

Access Box Developer Console:

Go to Box Developer Console
Sign in with your Box account


Create New Application:

Click "Create New App"
Choose "Custom App"
Select "Server Authentication (JWT)"
Name your app (e.g., "Raspberry Pi Barcode Scanner")



Step 2: Configure Application Settings

Set Application Scopes:

✅ Read all files and folders stored in Box
✅ Write all files and folders stored in Box
✅ Manage users


Configure Advanced Features:

✅ Generate user access tokens


Generate Public/Private Keypair:

In "Add and Manage Public Keys" section
Click "Generate a Public/Private Keypair"
Download the configuration JSON file



Step 3: Deploy Configuration

Place Config File:
bash# Copy the downloaded config file to your project
cp ~/Downloads/[downloaded-config-file].json ./config/box_config.json

# Secure the config file
chmod 600 ./config/box_config.json

Test Box Connection:
bashpython detailed_box_test.py


Step 4: Authorize Application

Submit for Authorization:

In Box Developer Console, click "Review and Submit"
Wait for approval (usually instant for personal apps)


Share Target Folder:

Create or identify your target folder in Box
Share it with your app's Service Account Email (found in app settings)
Grant "Co-owner" permissions



Running the Project
Development Testing

Activate Virtual Environment:
bashsource venv/bin/activate

Run Interactive Test:
bashpython src/barcode_scanner.py

Test Barcode Scanning:

Scan a barcode with your scanner
Verify logging in terminal and Excel file creation
Check logs/barcode_scanner.log for detailed output



Stopping the Test
Press Ctrl+C to stop the scanner gracefully.
Production Deployment
For reliable 24/7 operation, use systemd service management instead of cron jobs.
1. Create Systemd Service
Create the service file:
bashsudo tee /etc/systemd/system/barcode-scanner.service << EOF
[Unit]
Description=Barcode Scanner Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=/home/$USER/barcode-scanner-pi
Environment=PATH=/home/$USER/barcode-scanner-pi/venv/bin
ExecStart=/home/$USER/barcode-scanner-pi/venv/bin/python src/barcode_scanner.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/home/$USER/barcode-scanner-pi/data /home/$USER/barcode-scanner-pi/logs

[Install]
WantedBy=multi-user.target
EOF
2. Enable and Start Service
bash# Reload systemd configuration
sudo systemctl daemon-reload

# Enable service to start at boot
sudo systemctl enable barcode-scanner.service

# Start the service
sudo systemctl start barcode-scanner.service

# Check service status
sudo systemctl status barcode-scanner.service
3. Service Management Commands
bash# Check service status
sudo systemctl status barcode-scanner

# View real-time logs
sudo journalctl -u barcode-scanner -f

# Stop the service
sudo systemctl stop barcode-scanner

# Restart the service
sudo systemctl restart barcode-scanner

# Disable automatic startup
sudo systemctl disable barcode-scanner
Monitoring & Maintenance
Log Monitoring
Application Logs:
bash# View recent application logs
tail -f logs/barcode_scanner.log

# Search for errors
grep ERROR logs/barcode_scanner.log

# View logs with timestamps
tail -f logs/barcode_scanner.log | while read line; do echo "$(date): $line"; done
System Logs:
bash# View systemd service logs
sudo journalctl -u barcode-scanner -f

# View recent service logs
sudo journalctl -u barcode-scanner --since "1 hour ago"

# View logs from last boot
sudo journalctl -u barcode-scanner -b
Health Monitoring Script
Create a monitoring script:
bashtee monitor_barcode.sh << 'EOF'
#!/bin/bash
# Monitor barcode scanner service health

SERVICE_NAME="barcode-scanner"
LOG_FILE="/home/$USER/barcode-scanner-pi/logs/barcode_scanner.log"

# Check if service is running
if ! systemctl is-active --quiet $SERVICE_NAME; then
    echo "❌ Service $SERVICE_NAME is not running"
    exit 1
fi

# Check recent activity (no errors in last 10 minutes)
if tail -100 "$LOG_FILE" | grep -q "$(date '+%Y-%m-%d %H:%M' -d '10 minutes ago')"; then
    echo "✅ Service is healthy and active"
else
    echo "⚠️  No recent activity detected"
fi

# Show service status
systemctl status $SERVICE_NAME --no-pager -l
EOF

chmod +x monitor_barcode.sh
Automated Health Checks
Add to crontab for periodic health checks:
bashcrontab -e
Add this line:
bash# Check barcode scanner health every 30 minutes
*/30 * * * * /home/$USER/barcode-scanner-pi/monitor_barcode.sh >> /home/$USER/barcode-scanner-pi/logs/health_check.log 2>&1
Log Rotation
Set up log rotation to prevent disk space issues:
bashsudo tee /etc/logrotate.d/barcode-scanner << EOF
/home/$USER/barcode-scanner-pi/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 $USER $USER
}
EOF
Troubleshooting
Common Issues and Solutions
1. Service Won't Start
bash# Check service status for error details
sudo systemctl status barcode-scanner.service

# Check logs for specific errors
sudo journalctl -u barcode-scanner --since "10 minutes ago"

# Common fixes:
# - Verify file permissions
# - Check .env configuration
# - Validate Box config file
2. Box Upload Failures
bash# Test Box connection
python detailed_box_test.py

# Common causes:
# - Invalid Box configuration
# - Network connectivity issues
# - Folder permission problems
3. Barcode Scanner Not Detected
bash# Check USB devices
lsusb

# Check input devices
ls -la /dev/input/

# Test scanner manually
cat /dev/input/event0  # (replace event0 with your device)

# Check user permissions
groups $USER | grep input
4. Permission Errors
bash# Fix file permissions
chmod -R 755 /home/$USER/barcode-scanner-pi
chmod 600 /home/$USER/barcode-scanner-pi/.env
chmod 600 /home/$USER/barcode-scanner-pi/config/box_config.json

# Ensure user is in input group
sudo usermod -a -G input $USER
# Then logout and login again
Diagnostic Commands
bash# Check service status
sudo systemctl status barcode-scanner

# View configuration
python -c "
from src.barcode_scanner import Config
try:
    config = Config()
    print('✅ Configuration loaded successfully')
except Exception as e:
    print(f'❌ Configuration error: {e}')
"

# Test Box connection
python detailed_box_test.py

# Monitor resource usage
top -p $(pgrep -f barcode_scanner.py)
Project Structure
barcode-scanner-pi/
├── src/
│   └── barcode_scanner.py         # Main application (enhanced version)
├── config/
│   └── box_config.json           # Box JWT configuration (not in repo)
├── data/                         # Excel files storage
│   └── scanned_barcodes_*.xlsx   # Daily barcode logs
├── logs/                         # Application logs
│   ├── barcode_scanner.log       # Main application log
│   └── health_check.log          # Health monitoring log
├── tests/
│   ├── test_box_connection.py    # Basic Box connection test
│   └── detailed_box_test.py      # Comprehensive Box test
├── .env                          # Environment configuration
├── .env.example                  # Environment template
├── .gitignore                    # Git ignore file
├── requirements.txt              # Python dependencies
├── monitor_barcode.sh            # Health monitoring script
└── README.md                     # This documentation
Key Improvements Over Original
Reliability Enhancements

Systemd Service Management: More reliable than cron jobs
Retry Logic: Automatic recovery from temporary failures
Thread-Safe Operations: Prevents data corruption
Configuration Validation: Early error detection

Operational Improvements

Structured Logging: Better debugging and monitoring
Health Monitoring: Automated system health checks
Log Rotation: Prevents disk space issues
Security Hardening: Proper file permissions and service isolation

Development Experience

Comprehensive Testing: Multiple test scripts for validation
Clear Error Messages: Better troubleshooting information
Modular Design: Easier maintenance and updates

Security Considerations

All sensitive files have proper permissions (600)
Service runs with minimal privileges
Box JWT tokens are securely stored
Log files don't contain sensitive information
Regular security updates recommended

Maintenance Schedule
Daily: Monitor service status and logs
Weekly: Check disk space and log rotation
Monthly: Update system packages and dependencies
Quarterly: Review and rotate Box JWT credentials
License
This project is licensed under the MIT License - see the LICENSE file for details.
Support
For issues and questions:

Check the troubleshooting section
Review application logs
Test Box connection with provided scripts
Create an issue in the GitHub repository


Last Updated: January 2025
Version: 2.0 (Enhanced Production Release)