#!/usr/bin/env python3
"""
Test script to verify barcode scanner installation
"""
import sys
import os
sys.path.append('/home/pi/barcode-scanner')

try:
    from barcode_scanner import Config
    print("✓ Configuration module loaded successfully")
    
    config = Config()
    print("✓ Configuration validated successfully")
    print(f"✓ Base directory: {config.base_dir}")
    print(f"✓ Box config path: {config.box_config_path}")
    
    # Test imports
    import openpyxl
    print("✓ openpyxl imported successfully")
    
    import keyboard
    print("✓ keyboard imported successfully")
    
    from boxsdk import JWTAuth, Client
    print("✓ Box SDK imported successfully")
    
    print("\n🎉 Installation test completed successfully!")
    print("Next steps:")
    print("1. Edit .env file with your configuration")
    print("2. Edit box_config.json with your Box JWT credentials") 
    print("3. Start the service: sudo systemctl start barcode-scanner")
    
except Exception as e:
    print(f"❌ Installation test failed: {e}")
    sys.exit(1)
