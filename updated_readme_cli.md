# Raspberry Pi Barcode Scanner with Box Integration (CLI Mode)

A robust barcode scanning system designed for Raspberry Pi that automatically logs scans to Excel files and uploads them to Box cloud storage. **Optimized for CLI mode and 20+ Pi deployments.**

## Features

- **Real-time barcode scanning** via USB barcode scanner in CLI mode
- **Excel logging** with timestamps and status tracking
- **Automatic Box upload** with robust retry system and upload queue
- **Daily file rotation** at 00:01 with reliable upload processing
- **CLI mode optimized** - perfect for headless/industrial environments
- **Multi-device support** with unique device identification
- **Comprehensive error handling** and structured logging
- **Empty file management** (no upload of files without scans)
- **Production ready** for 20+ Pi deployments

## Prerequisites

- Raspberry Pi (tested on Pi 3B+ and Pi 4)
- Raspbian OS (Bullseye or later)
- USB Barcode Scanner (HID keyboard mode)
- Python 3.7+
- Box Developer Account with JWT application
- Internet connection

## 🚀 Quick Start (Recommended)

### One-Line Installation

```bash
cd /home/pi && git clone https://github.com/fortunatowashu/barcode-scanner-pi.git barcode-scanner && cd barcode-scanner && chmod +x install.sh && ./install.sh
```

The installation script will:
- ✅ Install all system dependencies (including CLI input support)
- ✅ Install keyboard library for CLI compatibility
- ✅ Create Python virtual environment and install packages
- ✅ Configure udev rules for barcode scanner access
- ✅ Set up kernel modules for CLI input handling
- ✅ Create `data/` and `logs/` directories
- ✅ Install and enable systemd service
- ✅ **Create configuration files interactively**
- ✅ **Set CLI mode as default boot target**

## 📋 Configuration

The installation script will create configuration files for you:

### 1. Device & Box Configuration (Interactive Setup)

During installation, you'll be prompted for:

```bash
# Device identification (make unique for each Pi)
Device ID: pi_warehouse_01
Device Location: Main Warehouse

# Box settings (get from Box Developer Console)
Target Folder ID: 123456789
Collaborator Email: manager@company.com
```

### 2. Box JWT Configuration

**After installation, you need to configure Box authentication:**

1. **Create JWT app in [Box Developer Console](https://app.box.com/developers/console)**
2. **Download the configuration file** (named like `1234567_config.json`)
3. **Replace the template file:**

```bash
cd /home/pi/barcode-scanner

# Option 1: Rename downloaded file
mv your_downloaded_*_config.json box_config.json

# Option 2: Copy content to existing template
nano box_config.json  # Paste your JWT config
```

## 🔧 Testing Your Installation

```bash
# Test the installation
cd /home/pi/barcode-scanner
python3 scripts/test_scanner.py

# Should show all green checkmarks ✓
```

## 🚀 Starting the Service

**After configuring Box credentials:**

```bash
# Reboot to CLI mode (done automatically by installer)
sudo reboot

# After reboot, start the service
sudo systemctl start barcode-scanner

# Check status
sudo systemctl status barcode-scanner

# View real-time logs
sudo journalctl -u barcode-scanner -f
```

## 📁 Project Structure

```
/home/pi/barcode-scanner/
├── barcode_scanner.py          # Main application (with robust upload system)
├── .env                        # Environment configuration (auto-created)
├── box_config.json            # Box JWT credentials (template created)
├── requirements.txt           # Python dependencies
├── install.sh                 # Enhanced installation script
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

1. **Service runs automatically** after reboot
2. **Scan barcodes** with your USB scanner
3. **Monitor via SSH:**
   ```bash
   ssh pi@192.168.1.100
   ./scripts/monitor.sh
   ```

### File Management

- **Excel files:** `scanned_barcodes_DEVICE_ID_YYYY-MM-DD.xlsx`
- **Daily rotation:** 00:01 with upload queue processing
- **Robust uploads:** Retry logic with exponential backoff
- **Empty file handling:** Deleted locally, not uploaded

## 🔍 Monitoring and Management

### Remote Monitoring (SSH)

```bash
# Quick status check
ssh pi@192.168.1.100 "./scripts/monitor.sh"

# Live log monitoring
ssh pi@192.168.1.100 "sudo journalctl -u barcode-scanner -f"

# Service control
ssh pi@192.168.1.100 "sudo systemctl restart barcode-scanner"
```

### Health Check Commands

```bash
# Service status
sudo systemctl status barcode-scanner

# Recent logs
sudo journalctl -u barcode-scanner -n 20

# Today's scan activity
sudo journalctl -u barcode-scanner --since today | grep "Logged barcode"

# Upload activity
sudo journalctl -u barcode-scanner --since today | grep "Successfully uploaded"
```

## 🛠️ Troubleshooting

### Service Won't Start

```bash
# Check configuration
python3 scripts/test_scanner.py

# Check Box credentials
python3 -m json.tool box_config.json

# View error logs
sudo journalctl -u barcode-scanner -xe
```

### Scanner Not Working

```bash
# Test hardware
cat  # Then scan barcode

# Check input devices
ls -la /dev/input/

# Check scanner detection
lsusb | grep -i scanner
```

### Box Upload Issues

```bash
# Test connectivity
ping box.com

# Check folder permissions in Box web interface
# Verify TARGET_FOLDER_ID in .env file

# Manual upload test
cd /home/pi/barcode-scanner
python3 box_uploader.py --test
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Service keeps restarting | Check box_config.json is valid JSON |
| Scanner not detected | Ensure scanner is in HID keyboard mode |
| Upload failures | Verify TARGET_FOLDER_ID and internet connection |
| No scan logs | Check `sudo journalctl -u barcode-scanner -f` while scanning |

## 🔄 Multi-Device Deployment (20+ Pis)

### Mass Deployment Script

```bash
# Create deployment script for multiple Pis
cat > deploy_all_pis.sh << 'EOF'
#!/bin/bash
# Deploy to multiple Pis

PI_LIST=(
    "192.168.1.101"
    "192.168.1.102"
    "192.168.1.103"
    # Add all your Pi IP addresses
)

for pi_ip in "${PI_LIST[@]}"; do
    echo "=== Deploying to Pi at $pi_ip ==="
    
    # Deploy and install
    ssh pi@$pi_ip "
        cd /home/pi && 
        git clone https://github.com/fortunatowashu/barcode-scanner-pi.git barcode-scanner && 
        cd barcode-scanner && 
        chmod +x install.sh && 
        ./install.sh
    "
    
    # Copy Box config (if using shared config)
    scp box_config.json pi@$pi_ip:/home/pi/barcode-scanner/
    
    echo "✅ Deployed to $pi_ip"
done
EOF

chmod +x deploy_all_pis.sh
./deploy_all_pis.sh
```

### Monitoring Multiple Pis

```bash
cat > monitor_all_pis.sh << 'EOF'
#!/bin/bash
# Monitor all barcode scanner Pis

PI_LIST=("192.168.1.101" "192.168.1.102" "192.168.1.103")

for pi_ip in "${PI_LIST[@]}"; do
    echo "=== Scanner Status for $pi_ip ==="
    
    if ping -c 1 -W 1 $pi_ip > /dev/null 2>&1; then
        ssh pi@$pi_ip "
            echo 'Service:' \$(sudo systemctl is-active barcode-scanner)
            echo 'Today scans:' \$(sudo journalctl -u barcode-scanner --since today | grep -c 'Logged barcode')
            echo 'Last scan:' \$(sudo journalctl -u barcode-scanner -n 1 --no-pager | grep 'Logged barcode' | tail -1 | cut -d' ' -f1-3,8-)
        " 2>/dev/null || echo "SSH failed"
    else
        echo "❌ Pi offline"
    fi
    echo
done
EOF

chmod +x monitor_all_pis.sh
```

## 🔐 Security and Management

### SSH Key Setup (Recommended)

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096

# Copy to all Pis
for pi in 192.168.1.{101..120}; do
    ssh-copy-id pi@$pi
done
```

### Firewall Configuration

```bash
# Basic firewall setup
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow from 192.168.1.0/24  # Local network only
```

## 🔄 Updates and Maintenance

### Manual Update

```bash
cd /home/pi/barcode-scanner
git pull
source venv/bin/activate
pip install -r requirements.txt --upgrade
sudo systemctl restart barcode-scanner
```

### Automated Updates

```bash
# Create auto-update script
cat > scripts/auto_update.sh << 'EOF'
#!/bin/bash
cd /home/pi/barcode-scanner
git pull
source venv/bin/activate
pip install -r requirements.txt --upgrade
sudo systemctl restart barcode-scanner
EOF

chmod +x scripts/auto_update.sh

# Add to crontab for weekly updates
(crontab -l 2>/dev/null; echo "0 2 * * 0 /home/pi/barcode-scanner/scripts/auto_update.sh") | crontab -
```

## 📈 Production Features

### Robust Upload System
- **Upload queue** with persistent worker thread
- **Retry logic** with exponential backoff
- **Graceful shutdown** - waits for uploads to complete
- **Comprehensive logging** for troubleshooting

### CLI Mode Optimizations
- **No GUI overhead** - saves ~200MB RAM per Pi
- **Faster boot times** - 15-30 seconds vs 45-60 seconds
- **Better reliability** - fewer components to fail
- **SSH-based management** - scriptable and automatable

### Error Recovery
- **Service auto-restart** on failures
- **File corruption handling** with recovery
- **Network timeout handling** with retries
- **Device reconnection** logic

## 🆘 Support and Troubleshooting

### Quick Diagnostic Commands

```bash
# Complete health check
cd /home/pi/barcode-scanner && python3 scripts/test_scanner.py

# Service diagnostic
sudo systemctl status barcode-scanner
sudo journalctl -u barcode-scanner --since "1 hour ago"

# Hardware check
lsusb  # Should show your scanner
ls -la /dev/input/  # Should show event devices

# Network check
ping box.com
```

### Remote Support

```bash
# Generate support report
cat > generate_support_report.sh << 'EOF'
#!/bin/bash
echo "=== Barcode Scanner Support Report ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "IP: $(hostname -I)"
echo
echo "=== Service Status ==="
sudo systemctl status barcode-scanner
echo
echo "=== Recent Logs ==="
sudo journalctl -u barcode-scanner -n 20
echo
echo "=== Configuration ==="
grep -v "SECRET\|KEY\|PASS" /home/pi/barcode-scanner/.env 2>/dev/null || echo "No .env file"
echo
echo "=== Hardware ==="
lsusb | grep -i scanner
ls -la /dev/input/
EOF

chmod +x generate_support_report.sh
```

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Built with Python and [openpyxl](https://openpyxl.readthedocs.io/)
- Box integration via [Box Python SDK](https://github.com/box/box-python-sdk)
- Keyboard monitoring with [keyboard](https://github.com/boppreh/keyboard)

---

**Version:** 2.0.0 (CLI Optimized)  
**Last Updated:** July 2025  
**Maintainer:** Fortunato Hernandez

## 📋 Quick Reference Card

**Essential Commands:**
```bash
# Installation (One-Line)
cd /home/pi && git clone https://github.com/fortunatowashu/barcode-scanner-pi.git barcode-scanner && cd barcode-scanner && chmod +x install.sh && ./install.sh

# Configuration
nano .env  # Edit device settings
mv *_config.json box_config.json  # Replace Box JWT config

# Testing
python3 scripts/test_scanner.py

# Service Management
sudo systemctl start barcode-scanner
sudo systemctl status barcode-scanner
sudo systemctl restart barcode-scanner

# Monitoring
./scripts/monitor.sh
sudo journalctl -u barcode-scanner -f

# Return to Desktop (if needed)
sudo systemctl set-default graphical.target && sudo reboot
```

**SSH Management (for 20+ Pis):**
```bash
# Monitor all Pis
./monitor_all_pis.sh

# Update all Pis
for pi in 192.168.1.{101..120}; do ssh pi@$pi "cd /home/pi/barcode-scanner && git pull && sudo systemctl restart barcode-scanner"; done

# Check all Pi status
for pi in 192.168.1.{101..120}; do echo "=== $pi ==="; ssh pi@$pi "sudo systemctl is-active barcode-scanner"; done
```

Print this section and keep it handy for managing your Pi fleet! 🖨️