# Raspberry Pi Barcode Scanner with Box Integration

A robust barcode scanning system designed for Raspberry Pi that automatically logs scans to Excel files and uploads them to Box cloud storage.

## Features

- **Real-time barcode scanning** via USB barcode scanner
- **Excel logging** with timestamps and status tracking
- **Automatic Box upload** of files containing scan data
- **Daily file rotation** at midnight
- **Auto-restart** on system reboot or crashes
- **Multi-device support** with unique device identification
- **Comprehensive error handling** and logging
- **Empty file management** (no upload of files without scans)

## Prerequisites

- Raspberry Pi (tested on Pi 3B+ and Pi 4)
- Raspbian OS (Bullseye or later)
- USB Barcode Scanner (HID keyboard mode)
- Python 3.7+
- Box Developer Account with JWT application
- Internet connection

## 🚀 Quick Start (Recommended)

### Option 1: One-Line Installation (If using public repo)

```bash
wget -O - https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/scripts/install.sh | bash
```

### Option 2: Manual Installation

1. **Update your Pi and install git:**
```bash
sudo apt-get update
sudo apt-get install -y git
```

2. **Clone or download the project:**
```bash
cd /home/pi
git clone https://github.com/YOUR_USERNAME/barcode-scanner.git
# OR if downloading manually, extract to /home/pi/barcode-scanner
```

3. **Run the installation script:**
```bash
cd barcode-scanner
chmod +x install.sh
./install.sh
```

The installation script will automatically:
- Install all system dependencies (including `kbd` package)
- Create Python virtual environment
- Install Python packages
- Create `data/` and `logs/` directories
- Set up proper file permissions
- Install and enable the systemd service
- Create example configuration files

## 📋 Configuration

After installation, you need to configure two files:

### 1. Environment Variables (.env)

```bash
nano /home/pi/barcode-scanner/.env
```

Edit the following values:
```bash
# Device identification (make unique for each Pi)
DEVICE_ID=pi_warehouse_01
DEVICE_LOCATION=Main Warehouse

# Paths (usually don't need to change)
BASE_DIR=/home/pi/barcode-scanner/data
BOX_CONFIG_PATH=/home/pi/barcode-scanner/box_config.json

# Box settings (get these from Box Developer Console)
TARGET_FOLDER_ID=your_box_folder_id_here
COLLABORATOR_EMAIL=manager@company.com

# Scanner settings
BARCODE_TIMEOUT=5          # Seconds to wait for complete barcode
MAX_RETRIES=3             # Box upload retry attempts
RETRY_DELAY=5             # Seconds between retries
LOG_LEVEL=INFO            # DEBUG, INFO, WARNING, ERROR
```

### 2. Box Configuration (box_config.json)

1. **Create a JWT application in [Box Developer Console](https://app.box.com/developers/console)**
2. **Generate a public/private keypair**
3. **Download the configuration file** (it will have a name like `1234567_config.json`)
4. **Rename and place the file:**

```bash
# Rename the downloaded Box config file
cd /home/pi/barcode-scanner
mv *_config.json box_config.json

# Edit if needed (optional - usually the downloaded file works as-is)
nano box_config.json
```

**Note:** The downloaded Box JWT file will have a random name like `123456789_config.json`. Simply rename it to `box_config.json` for the application to find it.

## 🔧 Testing Your Installation

Before starting the service, test the installation:

```bash
cd /home/pi/barcode-scanner
python3 scripts/test_scanner.py
```

You should see all green checkmarks ✓ if everything is installed correctly.

## 🚀 Starting the Service

Once configured, start the barcode scanner service:

```bash
# Start the service
sudo systemctl start barcode-scanner

# Check if it's running
sudo systemctl status barcode-scanner

# View real-time logs
sudo journalctl -u barcode-scanner -f
```

## 📁 Project Structure

```
/home/pi/barcode-scanner/
├── barcode_scanner.py          # Main application
├── .env                        # Environment configuration
├── box_config.json            # Box JWT credentials
├── requirements.txt           # Python dependencies
├── install.sh                 # Installation script
├── data/                      # Excel files directory (auto-created)
│   └── scanned_barcodes_*.xlsx
├── logs/                      # Application logs (auto-created)
│   └── barcode_scanner.log
└── scripts/                   # Utility scripts (auto-created)
    ├── barcode-scanner.service # Systemd service
    ├── test_scanner.py        # Installation test
    └── monitor.sh             # Monitoring script
```

## 📊 Usage

### Daily Operation

1. **Ensure the service is running:**
```bash
sudo systemctl status barcode-scanner
```

2. **Start scanning barcodes** with your USB scanner
3. **Monitor progress:**
```bash
# Quick status check
./scripts/monitor.sh

# View live logs
sudo journalctl -u barcode-scanner -f
```

### File Management

- **Excel files** are created daily with format: `scanned_barcodes_DEVICE_ID_YYYY-MM-DD.xlsx`
- **Files contain:** Device ID, Location, Barcode, Timestamp, Status
- **Daily rotation** happens at midnight
- **Automatic upload** to Box if files contain scan data
- **Empty files** are deleted, not uploaded

## 🔍 Monitoring and Troubleshooting

### Quick Health Check

```bash
# Use the monitoring script
cd /home/pi/barcode-scanner
./scripts/monitor.sh
```

### View Logs

```bash
# Service logs (real-time)
sudo journalctl -u barcode-scanner -f

# Last 50 entries
sudo journalctl -u barcode-scanner -n 50

# Application logs
tail -f /home/pi/barcode-scanner/logs/barcode_scanner.log

# Today's logs only
sudo journalctl -u barcode-scanner --since today
```

### Common Commands

```bash
# Restart the service
sudo systemctl restart barcode-scanner

# Stop the service  
sudo systemctl stop barcode-scanner

# Disable auto-start
sudo systemctl disable barcode-scanner

# Re-enable auto-start
sudo systemctl enable barcode-scanner
```

## 🛠️ Troubleshooting

### Service Won't Start

1. **Test the configuration:**
```bash
cd /home/pi/barcode-scanner
python3 scripts/test_scanner.py
```

2. **Check permissions:**
```bash
sudo chown -R pi:pi /home/pi/barcode-scanner
```

3. **View error logs:**
```bash
sudo journalctl -u barcode-scanner -xe
```

### Barcode Scanner Not Working

1. **Verify scanner mode:** Scanner must be in HID keyboard mode
2. **Test in text editor:** Open a text editor and scan - you should see the barcode
3. **Check USB connection:**
```bash
lsusb  # Should show your scanner
```
4. **Try different USB port**

### Box Upload Failures

1. **Test internet connectivity:**
```bash
ping box.com
```

2. **Validate Box config:**
```bash
cd /home/pi/barcode-scanner
python -m json.tool box_config.json
# or if you haven't renamed it yet:
python -m json.tool *_config.json
```

3. **Check Box folder permissions** in Box web interface
4. **Verify TARGET_FOLDER_ID** in .env file

### Installation Issues

| Issue | Solution |
|-------|----------|
| Permission denied | Run install.sh as pi user, not root |
| Python packages fail | Ensure python3-dev is installed |
| Service fails to start | Check .env and box_config.json configuration |
| Keyboard not detected | Install kbd package: `sudo apt-get install kbd` |
| No internet during install | Connect Pi to internet before running install.sh |

## 🔄 Multi-Device Deployment

To deploy to multiple Raspberry Pis:

1. **Use unique DEVICE_ID** for each Pi in .env
2. **Create separate Box JWT configs** for each device (recommended for security)
3. **Use same TARGET_FOLDER_ID** if sharing the same Box folder

### Deployment Script for Multiple Pis

```bash
# Create a deployment script
cat > deploy_to_pi.sh << 'EOF'
#!/bin/bash
PI_IP=$1
if [ -z "$PI_IP" ]; then
    echo "Usage: $0 <pi_ip_address>"
    exit 1
fi

echo "Deploying to Pi at $PI_IP..."
scp -r * pi@$PI_IP:/home/pi/barcode-scanner/
ssh pi@$PI_IP "cd /home/pi/barcode-scanner && ./install.sh"
EOF

chmod +x deploy_to_pi.sh

# Deploy to a Pi
./deploy_to_pi.sh 192.168.1.100
```

## 🔐 Security Considerations

1. **Protect credentials:**
```bash
chmod 600 .env box_config.json
```

2. **Regular updates:**
```bash
sudo apt-get update && sudo apt-get upgrade
```

3. **Network security:**
   - Use firewall rules if exposed to internet
   - Consider VPN for remote access
   - Use separate Box service accounts per device

## 📈 Monitoring Multiple Devices

Create a monitoring script for multiple Pis:

```bash
cat > monitor_all.sh << 'EOF'
#!/bin/bash
# Monitor multiple Pi scanners
PI_LIST=("192.168.1.100" "192.168.1.101" "192.168.1.102")

for pi in "${PI_LIST[@]}"; do
    echo "=== Scanner Status for $pi ==="
    ssh pi@$pi "cd /home/pi/barcode-scanner && ./scripts/monitor.sh"
    echo
done
EOF
```

## 🔄 Updating

### Manual Update

```bash
cd /home/pi/barcode-scanner
git pull
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart barcode-scanner
```

### Automatic Updates (Optional)

```bash
# Create auto-update script
cat > scripts/auto_update.sh << 'EOF'
#!/bin/bash
cd /home/pi/barcode-scanner
git pull
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart barcode-scanner
EOF

chmod +x scripts/auto_update.sh

# Add to crontab for daily updates
(crontab -l 2>/dev/null; echo "0 2 * * * /home/pi/barcode-scanner/scripts/auto_update.sh") | crontab -
```

## 📝 Example Workflow

1. **Fresh Pi Setup:**
```bash
# SSH into Pi
ssh pi@your_pi_ip

# Download and run installation
cd /home/pi
git clone https://your-repo/barcode-scanner.git
cd barcode-scanner
./install.sh
```

2. **Configure:**
```bash
# Edit configuration files
nano .env
nano box_config.json
```

3. **Test and Start:**
```bash
# Test installation
python3 scripts/test_scanner.py

# Start service
sudo systemctl start barcode-scanner

# Monitor
./scripts/monitor.sh
```

4. **Daily Monitoring:**
```bash
# Quick check
./scripts/monitor.sh

# If issues, check logs
sudo journalctl -u barcode-scanner -f
```

## 🆘 Support

If you encounter issues:

1. **Check the logs** first: `sudo journalctl -u barcode-scanner -xe`
2. **Run the test script**: `python3 scripts/test_scanner.py`
3. **Verify configuration** files are properly set
4. **Check USB scanner** is working in text editor
5. **Verify internet connectivity** for Box uploads

For additional support:
- Review this README thoroughly
- Check Box Developer Console for JWT app status
- Ensure all prerequisites are met
- Contact your system administrator

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with Python and [openpyxl](https://openpyxl.readthedocs.io/)
- Box integration via [Box Python SDK](https://github.com/box/box-python-sdk)  
- Keyboard monitoring with [keyboard](https://github.com/boppreh/keyboard)

---

**Version:** 1.0.0  
**Last Updated:** January 2025  
**Maintainer:** Your Name

## 📋 Quick Reference Card

**Essential Commands:**
```bash
# Installation
./install.sh

# Configuration  
nano .env && nano box_config.json

# Test
python3 scripts/test_scanner.py

# Service Control
sudo systemctl start barcode-scanner
sudo systemctl status barcode-scanner
sudo systemctl restart barcode-scanner

# Monitoring
./scripts/monitor.sh
sudo journalctl -u barcode-scanner -f

# Troubleshooting
sudo journalctl -u barcode-scanner -xe
```

Print this section and keep it near your Pi for quick reference! 🖨️
