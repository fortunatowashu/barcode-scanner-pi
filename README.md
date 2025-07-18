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

## Quick Start

### One-Line Installation (Public Repo)

```bash
wget -O - https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/scripts/setup_pi.sh | bash
```

### Manual Installation

1. **Clone the repository:**
```bash
cd /home/pi
git clone https://github.com/YOUR_USERNAME/barcode-scanner.git
cd barcode-scanner
```

2. **Run the installation script:**
```bash
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

3. **Configure your credentials:**
```bash
# Copy and edit environment file
cp .env.example .env
nano .env

# Copy and edit Box configuration
cp box_config.example.json box_config.json
nano box_config.json
```

4. **Start the service:**
```bash
sudo systemctl start barcode-scanner
sudo systemctl enable barcode-scanner
```

## Configuration

### Environment Variables (.env)

```bash
# Device identification
DEVICE_ID=pi_warehouse_01
DEVICE_LOCATION=Main Warehouse

# Paths
BASE_DIR=/home/pi/barcode-scanner/data
BOX_CONFIG_PATH=/home/pi/barcode-scanner/box_config.json

# Box settings
TARGET_FOLDER_ID=your_box_folder_id_here
COLLABORATOR_EMAIL=manager@company.com

# Scanner settings
BARCODE_TIMEOUT=5          # Seconds to wait for complete barcode
MAX_RETRIES=3             # Box upload retry attempts
RETRY_DELAY=5             # Seconds between retries
LOG_LEVEL=INFO            # DEBUG, INFO, WARNING, ERROR
```

### Box Configuration

1. Create a JWT application in [Box Developer Console](https://app.box.com/developers/console)
2. Generate a public/private keypair
3. Download the configuration file
4. Place it as `box_config.json` in the project directory

## Project Structure

```
/home/pi/barcode-scanner/
├── barcode_scanner.py          # Main application
├── .env                        # Environment configuration
├── box_config.json            # Box JWT credentials
├── requirements.txt           # Python dependencies
├── data/                      # Excel files directory
│   └── scanned_barcodes_*.xlsx
├── logs/                      # Application logs
│   └── barcode_scanner.log
└── scripts/                   # Utility scripts
    ├── install.sh            # Installation script
    ├── barcode-scanner.service # Systemd service
    └── auto_update.sh        # Auto-update script
```

## Usage

### Starting/Stopping the Service

```bash
# Start the scanner
sudo systemctl start barcode-scanner

# Stop the scanner
sudo systemctl stop barcode-scanner

# Restart the scanner
sudo systemctl restart barcode-scanner

# Check status
sudo systemctl status barcode-scanner
```

### Viewing Logs

```bash
# Service logs
sudo journalctl -u barcode-scanner -f

# Application logs
tail -f /home/pi/barcode-scanner/logs/barcode_scanner.log

# Today's logs only
sudo journalctl -u barcode-scanner --since today
```

### Scanning Barcodes

1. Ensure the service is running
2. Scan barcodes with your USB scanner
3. Each scan is automatically logged to the daily Excel file
4. Files are uploaded to Box after midnight (if they contain scans)

## File Management

### Excel Files

- Created daily with format: `scanned_barcodes_[DEVICE_ID]_YYYY-MM-DD.xlsx`
- Contains columns: Device ID, Location, Barcode, Timestamp, Status
- Automatically rotated at midnight
- Only uploaded if containing actual scan data

### Box Upload

- Files upload automatically after daily rotation
- Failed uploads retry based on MAX_RETRIES setting
- Empty files are deleted, not uploaded
- Collaborators automatically added to Box folder

## Monitoring

### Check Service Health

```bash
# Quick health check
systemctl is-active barcode-scanner

# Detailed status
sudo systemctl status barcode-scanner

# Last 50 log entries
sudo journalctl -u barcode-scanner -n 50
```

### Monitor Multiple Devices

```bash
# If managing multiple Pis
./scripts/monitor_all_pis.sh
```

## Troubleshooting

### Service Won't Start

1. Check permissions:
```bash
sudo chown -R pi:pi /home/pi/barcode-scanner
sudo chmod -R 755 /home/pi/barcode-scanner
```

2. Test manually:
```bash
cd /home/pi/barcode-scanner
source venv/bin/activate
python barcode_scanner.py
```

3. Check system logs:
```bash
sudo journalctl -xe
```

### Barcode Scanner Not Working

1. Verify scanner is in HID keyboard mode
2. Test scanner in a text editor
3. Check USB connection:
```bash
lsusb  # Should show your barcode scanner
```

### Box Upload Failures

1. Verify internet connectivity:
```bash
ping box.com
```

2. Check Box credentials:
```bash
# Validate JSON syntax
python -m json.tool box_config.json
```

3. Verify folder permissions in Box web interface

### Common Issues

| Issue | Solution |
|-------|----------|
| "Permission denied" on keyboard | Service must run as root for keyboard access |
| Excel file corrupted | Automatically handled - creates new file |
| Network timeout | Increase RETRY_DELAY in .env |
| Box authentication fails | Regenerate JWT credentials in Box Console |

## Updating

### Manual Update

```bash
cd /home/pi/barcode-scanner
git pull
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart barcode-scanner
```

### Automatic Updates

Enable the auto-update cron job:
```bash
# Edit crontab
crontab -e

# Add this line for hourly updates
0 * * * * /home/pi/barcode-scanner/scripts/auto_update.sh
```

## Security Considerations

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

## Multi-Device Deployment

For deploying to multiple Raspberry Pis:

1. Create unique Box JWT configs for each device
2. Use the deployment script:
```bash
./scripts/deploy_multi_pi.sh
```

3. Monitor all devices:
```bash
./scripts/monitor_all_pis.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the [troubleshooting section](#troubleshooting)
2. Review logs in `/home/pi/barcode-scanner/logs/`
3. Open an issue on GitHub
4. Contact your system administrator

## Acknowledgments

- Built with Python and [openpyxl](https://openpyxl.readthedocs.io/)
- Box integration via [Box Python SDK](https://github.com/box/box-python-sdk)
- Keyboard monitoring with [keyboard](https://github.com/boppreh/keyboard)

---

**Version:** 1.0.0  
**Last Updated:** January 2024  
**Maintainer:** Fortunato Hernandez 