#!/bin/bash
# This script continuously runs the barcode_scanner.py script.
while true; do
    echo "Starting barcode_scanner.py at $(date)"
    /home/washudcm/barcode_project/venv/bin/python /home/pi/barcode_project/barcode_scanner.py >> /home/pi/barcode_project/barcode_scanner.log 2>&1
    echo "barcode_scanner.py exited with code $? at $(date). Restarting in 5 seconds..."
    sleep 5
done

