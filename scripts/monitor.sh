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
