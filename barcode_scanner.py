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

# Import Box SDK JWT classes
from boxsdk import JWTAuth, Client

# --- Global Variables & Environment Setup ---
BASE_DIR = "/home/washudcm/barcode_project"
load_dotenv(os.path.join(BASE_DIR, ".env"))

BOX_CONFIG_PATH = os.getenv("BOX_CONFIG_PATH")  # e.g., /home/washudcm/barcode_project/config.json
TARGET_FOLDER_ID = os.getenv("TARGET_FOLDER_ID")  # Personal target folder ID (from Box web)
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
    add_folder_collaborator(TARGET_FOLDER_ID, COLLABORATOR_EMAIL)
    # Schedule the rotation (for example, daily at midnight)
    schedule.every().day.at("00:00").do(rotate_excel)
    keyboard.on_press(on_barcode_input)
    print("[READY] Barcode scanner service is running...")
    while True:
        schedule.run_pending()
        time.sleep(1)

if __name__ == "__main__":
    main()
