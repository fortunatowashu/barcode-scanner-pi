# Barcode Scanner Project on Raspberry Pi

## Overview

This project enables a headless Raspberry Pi to capture barcode input from a connected barcode scanner and log the scanned data—with timestamps—into an Excel file. Additionally, the project integrates with Box to automatically upload the Excel file daily and add your personal Box account as a collaborator so that the file appears in your account. Box JWT authentication is used for secure communication with Box.

> **Important Note:**  
> The Python **keyboard** library has been patched to bypass root and dumpkeys issues in a headless environment. This project assumes that the Raspberry Pi is configured to boot to the command-line interface (CLI) with auto-login enabled.

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Requirements](#requirements)
4. [Installation & Setup](#installation--setup)
5. [Configuration](#configuration)
   - [Box Integration Setup](#box-integration-setup)
6. [Cloning the Repository](#cloning-the-repository)
7. [Full Code Listing](#full-code-listing)
   - [barcode_scanner.py](#barcode_scannerpy)
   - [box_helpers.py](#box_helperspy)
   - [run_barcode.sh](#run_barcodesh)
8. [Running the Project](#running-the-project)
   - [Interactive Testing](#interactive-testing)
   - [Automatic Startup via Cron](#automatic-startup-via-cron)
9. [Logging & Troubleshooting](#logging--troubleshooting)
10. [Project Structure](#project-structure)
11. [License](#license)
12. [Summary](#summary)

## Features

- **Barcode Input Capture:** Captures barcode input using a patched version of the **keyboard** library.
- **Excel Logging:** Logs scanned barcodes along with timestamps into an Excel file (named by the current date, e.g., `scanned_barcodes_YYYY-MM-DD.xlsx`).
- **Box Integration:** Automatically uploads the rotated Excel file to a designated Box folder using Box JWT authentication and adds your personal Box account as a collaborator (with the "co-owner" role).
- **Automatic Restart:** A bash wrapper script continuously runs the Python script and restarts it if it crashes.
- **Automatic Startup via Cron:** Cron’s `@reboot` directive launches the wrapper script automatically at boot.

## Requirements

- **Hardware & OS:**  
  - Raspberry Pi running Raspberry Pi OS configured to boot to CLI (with auto-login).
- **Software:**  
  - Python 3.11 or later  
  - A Python virtual environment (recommended)
  - Required Python libraries:
    - **keyboard** (patched version)
    - **openpyxl**
    - **python-dotenv**
    - **boxsdk** (for Box integration)
- **Utilities:**  
  - Cron  
  - Bash

## Installation & Setup

### 1. Prepare Your Project Directory

Place all project files in a directory on your Raspberry Pi (e.g., `/home/washudcm/barcode_project`).

### 2. Create and Activate a Virtual Environment

```bash
cd /home/washudcm/barcode_project
python3 -m venv venv
source venv/bin/activate
```
### 3. Install Dependencies
Within your virtual environment, install the required packages:

```bash
pip install keyboard openpyxl python-dotenv boxsdk
```
### 4. Patch the Keyboard Library
To bypass root and dumpkeys issues in a headless environment:

Open the file:
```bash
Copy
sudo nano venv/lib/python3.11/site-packages/keyboard/_nixcommon.py
```
Locate the ensure_root() function and change it to:
```python
def ensure_root():
    # Bypass root check; assume necessary permissions are provided via capabilities/udev.
    pass
```
Save (Ctrl+O, Enter) and exit (Ctrl+X).
### 5. Test the Script Interactively
Run the main script to ensure it functions properly:

```bash
venv/bin/python barcode_scanner.py
```
Verify that the initialization messages appear and that barcode input is captured and logged to an Excel file.

### Configuration
Create a .env File
In your project directory, create a file named .env:

```bash
nano .env
```
Insert the following content (adjust values as needed):

```ini
# Box Integration Settings
BOX_CONFIG_PATH="/home/washudcm/barcode_project/config.json"
TARGET_FOLDER_ID="YOUR_BOX_FOLDER_ID"
COLLABORATOR_EMAIL="your_personal_email@domain.com"

# Barcode Scanner Configuration:
# Ensure that your barcode scanner is in keyboard wedge mode.
```
Save and exit.

### Box Integration Setup
1.Create a Box JWT Application:
   -Log in to the Box Developer Console.
   -Create a new JWT application.
   -Configure the application with the required scopes and permissions.
2.Download the config.json File:
   -After configuring your app, download the config.json file. Keep this file private as it contains sensitive authentication details.
3.Place the JSON File in Your Project Directory:
   -Copy the downloaded config.json file into your project directory (e.g., /home/washudcm/barcode_project).
   -If you prefer not to push the actual file to GitHub, rename it to config.example.json and add the real config.json to your .gitignore.
4.Update the .env File:
   -Ensure that the BOX_CONFIG_PATH variable in your .env file points to the location of your config.json file.
The Box integration is handled in the box_helpers.py file, which uses the JWT credentials to authenticate, upload the Excel file, and add your personal Box account as a collaborator.

### Cloning the Repository
Once your project is uploaded to GitHub, you can clone it on any Raspberry Pi using the CLI:

```bash
git clone https://github.com/yourusername/barcode-scanner-pi.git
cd barcode-scanner-pi
```
Then follow the Installation & Setup instructions to create a virtual environment, install dependencies, and configure your .env file.

### Full Code Listing
### A. barcode_scanner.py
```python
#!/usr/bin/env python3
"""
Barcode Scanner Project with Box Upload (JWT Authentication and Collaboration):
- Logs barcode scans to an Excel file.
- Rotates (renames and uploads) the Excel file daily.
- Uploads the file using Box JWT authentication.
- Automatically adds your personal Box account as a collaborator so the file appears in your account.
"""

import os
import time
import schedule
import base64
import mimetypes
from datetime import datetime, timedelta

import openpyxl
from openpyxl.utils.exceptions import InvalidFileException
from dotenv import load_dotenv
import keyboard  # Requires root or proper udev rules on Linux

# Import Box SDK JWT classes for Box integration
from boxsdk import JWTAuth, Client

# --- Global Variables & Environment Setup ---
BASE_DIR = "/home/washudcm/barcode_project"
load_dotenv(os.path.join(BASE_DIR, ".env"))

BOX_CONFIG_PATH = os.getenv("BOX_CONFIG_PATH")  # e.g., /home/washudcm/barcode_project/config.json
TARGET_FOLDER_ID = os.getenv("TARGET_FOLDER_ID")  # Personal target folder ID from Box web
COLLABORATOR_EMAIL = os.getenv("COLLABORATOR_EMAIL")  # Your personal email to share the file with

# Excel logging settings
excel_path = ""
barcode_buffer = []  # For collecting barcode keystrokes

# --- Function to Create a Box Client Using JWT ---
def get_box_client():
    try:
        auth = JWTAuth.from_settings_file(BOX_CONFIG_PATH)
        client = Client(auth)
        return client
    except Exception as e:
        print(f"[ERROR] Failed to authenticate with Box: {e}")
        return None

# --- Function to Add a Collaborator ---
def add_folder_collaborator(folder_id, collaborator_email):
    client = get_box_client()
    if not client:
        print("[ERROR] Box client not available. Cannot add collaborator to folder.")
        return
    payload = {
        "item": {"type": "folder", "id": folder_id},
        "accessible_by": {"type": "user", "login": collaborator_email},
        "role": "co-owner"
    }
    try:
        response = client.session.post("https://api.box.com/2.0/collaborations", json=payload)
        if response.status_code in [200, 201, 202]:
            print(f"[BOX] Added collaborator {collaborator_email} to folder ID {folder_id}")
        elif response.status_code == 400 and "user_already_collaborator" in response.text:
            print(f"[BOX] Collaborator {collaborator_email} is already added to folder ID {folder_id}.")
        else:
            print(f"[ERROR] Failed to add collaborator to folder: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"[ERROR] Exception during folder collaborator addition: {e}")

# --- Function to Upload File to Box ---
def upload_to_box(file_path):
    if not os.path.exists(file_path):
        print(f"[BOX] File not found, skipping upload: {file_path}")
        return

    client = get_box_client()
    if not client:
        print("[ERROR] Box client not available. Cannot upload file.")
        return

    try:
        folder_id = TARGET_FOLDER_ID
        file_name = os.path.basename(file_path)
        uploaded_file = client.folder(folder_id).upload(file_path, file_name=file_name)
        print(f"[BOX] Successfully uploaded {file_path} as file ID {uploaded_file.id}")
    except Exception as e:
        print(f"[ERROR] Box upload failed: {e}")

# --- Excel File Management and Barcode Logging Functions ---
def initialize_excel():
    global excel_path
    today_str = datetime.now().strftime("%Y-%m-%d")
    excel_path = os.path.join(BASE_DIR, f"scanned_barcodes_{today_str}.xlsx")
    
    if not os.path.exists(excel_path):
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.append(["Barcode", "Timestamp"])
        wb.save(excel_path)
        print(f"[INIT] Created new Excel file: {excel_path}")
    else:
        print(f"[INIT] Using existing Excel file: {excel_path}")

def log_barcode(barcode):
    global excel_path
    try:
        wb = openpyxl.load_workbook(excel_path)
        ws = wb.active
        ws.append([barcode, datetime.now().strftime("%Y-%m-%d %H:%M:%S")])
        wb.save(excel_path)
        print(f"[SCAN] Logged barcode: {barcode}")
    except InvalidFileException as e:
        print(f"[ERROR] Failed to log barcode due to invalid file: {e}")
        handle_file_corruption(barcode)
    except Exception as e:
        print(f"[ERROR] Failed to log barcode: {e}")
        handle_file_corruption(barcode)

def handle_file_corruption(barcode):
    global excel_path
    timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
    corrupted_file = excel_path.replace(".xlsx", f"_CORRUPTED_{timestamp_str}.xlsx")
    try:
        os.rename(excel_path, corrupted_file)
        print(f"[CORRUPT] Renamed corrupt file to: {corrupted_file}")
    except Exception as err:
        print(f"[ERROR] Could not rename corrupted file: {err}")
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.append(["Barcode", "Timestamp"])
    ws.append([barcode, datetime.now().strftime("%Y-%m-%d %H:%M:%S")])
    wb.save(excel_path)
    print(f"[CORRUPT] Created new Excel file: {excel_path}")

def rotate_excel():
    global excel_path
    yesterday_str = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
    yesterday_file = os.path.join(BASE_DIR, f"scanned_barcodes_{yesterday_str}.xlsx")
    if os.path.exists(excel_path):
        try:
            os.rename(excel_path, yesterday_file)
            print(f"[ROTATE] Renamed {excel_path} to {yesterday_file}")
            upload_to_box(yesterday_file)
        except Exception as e:
            print(f"[ERROR] Rotation failed: {e}")
    initialize_excel()

def on_barcode_input(event):
    global barcode_buffer
    if event.name == "enter":
        barcode = "".join(barcode_buffer)
        barcode = barcode.replace("space", " ")
        log_barcode(barcode)
        barcode_buffer = []
    else:
        if len(event.name) == 1 or event.name == "space":
            barcode_buffer.append(event.name)

# --- Main Execution ---
def main():
    initialize_excel()
    # Automatically add your personal Box account as a collaborator.
    add_folder_collaborator(TARGET_FOLDER_ID, COLLABORATOR_EMAIL)
    # Schedule the Excel file rotation (daily at midnight)
    schedule.every().day.at("00:00").do(rotate_excel)
    keyboard.on_press(on_barcode_input)
    print("[READY] Barcode scanner service is running...")
    while True:
        schedule.run_pending()
        time.sleep(1)

if __name__ == "__main__":
    main()
```
### B. box_helpers.py
```python
#!/usr/bin/env python3
"""
Box Helpers Module
- Contains functions for authenticating with Box and adding collaborators.
"""

from boxsdk import JWTAuth, Client

def get_box_client():
    """
    Authenticates using Box JWT and returns a Box client.
    Reads configuration from 'config.json' in the project directory.
    """
    try:
        auth = JWTAuth.from_settings_file("config.json")
        client = Client(auth)
        return client
    except Exception as e:
        print(f"[ERROR] Failed to authenticate with Box: {e}")
        return None

def add_folder_collaborator(folder_id, collaborator_email):
    """
    Adds a collaborator to a Box folder.
    
    Parameters:
      folder_id (str): The ID of the Box folder.
      collaborator_email (str): The email address of the user to add as a collaborator.
      
    The function uses the Box API to add the collaborator with the 'co-owner' role.
    This ensures that the uploaded file appears in your personal Box account.
    If the user is already a collaborator, it logs a message.
    """
    client = get_box_client()
    if not client:
        print("[ERROR] Box client not available. Cannot add collaborator to folder.")
        return
    payload = {
        "item": {"type": "folder", "id": folder_id},
        "accessible_by": {"type": "user", "login": collaborator_email},
        "role": "co-owner"
    }
    try:
        response = client.session.post("https://api.box.com/2.0/collaborations", json=payload)
        if response.status_code in [200, 201, 202]:
            print(f"[BOX] Added collaborator {collaborator_email} to folder ID {folder_id}")
        elif response.status_code == 400 and "user_already_collaborator" in response.text:
            print(f"[BOX] Collaborator {collaborator_email} is already added to folder ID {folder_id}.")
        else:
            print(f"[ERROR] Failed to add collaborator to folder: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"[ERROR] Exception during folder collaborator addition: {e}")
```
### C. run_barcode.sh
```bash
#!/bin/bash
# run_barcode.sh - Wrapper script to continuously run barcode_scanner.py

cd /home/washudcm/barcode_project
while true; do
    echo "Starting barcode_scanner.py at $(date)" >> barcode_scanner.log
    venv/bin/python barcode_scanner.py >> barcode_scanner.log 2>&1
    echo "barcode_scanner.py exited with code $? at $(date). Restarting in 5 seconds..." >> barcode_scanner.log
    sleep 5
done
```
Make the script executable:

```bash
chmod +x run_barcode.sh
```
### Running the Project
### Interactive Testing
1. Open a Terminal and Navigate to the Project Directory:

```bash
cd /home/washudcm/barcode_project
```
2. Activate the Virtual Environment:

```bash
source venv/bin/activate
```
3. Run the Main Script:

```bash
python barcode_scanner.py
```
4. Test the Scanner:
Scan a barcode and verify that key events are printed in the terminal and that the barcode is logged in the corresponding Excel file.

### Automatic Startup via Cron
1. Edit Your Crontab:

```bash
crontab -e
```
2. Add the Following Line to Launch the Wrapper Script at Boot:

```cron
@reboot /home/washudcm/barcode_project/run_barcode.sh >> /home/washudcm/barcode_project/run_barcode_cron.log 2>&1
```
3. Save and Exit the Crontab.

4. Reboot the Raspberry Pi:

```bash
sudo reboot
```
5. Verify the Logs:
After reboot, check the log files:

```bash
tail -f /home/washudcm/barcode_project/run_barcode_cron.log
tail -f /home/washudcm/barcode_project/barcode_scanner.log
```
### Logging & Troubleshooting
-Log Files:

   -barcode_scanner.log: Contains all output (both stdout and errors) from the Python script.
   -run_barcode_cron.log: Contains output from the cron job that launches the wrapper script.
-Process Monitoring:
   -To check running processes, run:

   ```bash
ps aux | grep barcode_scanner.py
```
   -Common Issues:

      -Scanner Reconnection:
      If the barcode scanner is unplugged and reconnected, the input device handle may be lost. Additional logic might be needed to detect and reconnect the scanner.
      -Permissions:
      Ensure that your user is in the "input" group and that any required udev rules are configured.
      -Dumpkeys Errors:
      The patched keyboard library should handle dumpkeys errors gracefully.
### Project Structure
```pgsql
barcode_project/
├── barcode_scanner.py         # Main Python script with Box integration
├── box_helpers.py             # Contains Box API functions (JWT authentication and adding collaborators)
├── run_barcode.sh             # Bash wrapper script to continuously run the Python script
├── README.md                  # This documentation file
├── .env.example               # Example environment configuration file
├── config.example.json        # Example Box JWT configuration file
├── .gitignore                 # Git ignore file
├── barcode_scanner.log        # Log file for script output (auto-generated)
├── run_barcode_cron.log       # Log file for cron job output (auto-generated)
└── venv/                      # Python virtual environment directory (ignored)
```

### Summary
   -Project Overview:
      -The Barcode Scanner Project captures barcode input from a scanner on a headless Raspberry Pi using a patched version of the keyboard library. It logs scanned data to an Excel file and integrates with Box to upload rotated files while automatically adding your personal Box account as a collaborator.

   -Setup & Installation:
      -Create a Python virtual environment, install dependencies, patch the keyboard library, and configure environment variables using a .env file. For Box integration, obtain the config.json file from the Box Developer Console and place it in your project directory (or use a template like config.example.json).

   -Running the Project:
      -The project can be tested interactively and is set to start automatically via a cron @reboot job that runs a bash wrapper script (run_barcode.sh). This wrapper script ensures that the Python script is restarted if it crashes.

   -Cloning the Repository:
      -To replicate the project on another Raspberry Pi, clone the repository using:

```bash
git clone https://github.com/yourusername/barcode-scanner-pi.git
cd barcode-scanner-pi
```
   Then follow the Installation & Setup instructions.

   -Logging & Troubleshooting:
      -Log files (barcode_scanner.log and run_barcode_cron.log) capture all output and errors. Use standard Linux commands to monitor processes and troubleshoot issues.


