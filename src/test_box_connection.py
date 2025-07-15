#!/usr/bin/env python3
"""
Test script to verify Box connection and configuration
"""

import os
import json
from dotenv import load_dotenv
from boxsdk import JWTAuth, Client

def test_box_connection():
    # Load environment variables
    load_dotenv()
    
    box_config_path = os.getenv("BOX_CONFIG_PATH")
    target_folder_id = os.getenv("TARGET_FOLDER_ID")
    
    print(f"Testing Box connection...")
    print(f"Config path: {box_config_path}")
    print(f"Target folder ID: {target_folder_id}")
    
    try:
        # Test config file exists and is valid
        if not os.path.exists(box_config_path):
            print(f"❌ Config file not found: {box_config_path}")
            return False
        
        with open(box_config_path, 'r') as f:
            config_data = json.load(f)
            print(f"✅ Config file loaded successfully")
        
        # Test Box authentication
        auth = JWTAuth.from_settings_file(box_config_path)
        client = Client(auth)
        
        # Test user access
        user = client.user().get()
        print(f"✅ Authenticated as: {user.name} ({user.login})")
        
        # Test folder access
        folder = client.folder(target_folder_id)
        folder_info = folder.get()
        print(f"✅ Target folder accessible: {folder_info.name}")
        
        # Test folder permissions
        items = folder.get_items(limit=5)
        print(f"✅ Can list folder contents ({len(list(items))} items)")
        
        print("\n🎉 All tests passed! Box connection is working correctly.")
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = test_box_connection()
    exit(0 if success else 1)