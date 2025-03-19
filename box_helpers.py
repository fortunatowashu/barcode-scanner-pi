import os
from boxsdk import JWTAuth, Client
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.realpath(__file__))
load_dotenv(os.path.join(BASE_DIR, ".env"))

BOX_CONFIG_PATH = os.getenv("BOX_CONFIG_PATH")
TARGET_FOLDER_ID = os.getenv("TARGET_FOLDER_ID")
COLLABORATOR_EMAIL = os.getenv("COLLABORATOR_EMAIL")

def get_box_client():
	try:
		auth = JWTAuth.from_settings_file(BOX_CONFIG_PATH)
		client = Client(auth)
		return client
	except Exception as e:
		print(f"[ERROR] Failed to authenticate with Box: {e}")
		return None
		
def list_collaborations(file_id):
	client = get_box_client()
	collaborations = client.file(file_id).get_collaborations()
	for collab in collaborations:
		print(f"Collaboration ID: {collab.id}, Role: {collab.role}, Accessible By: {collab.accessible_by.login}")
		
		
def update_collaboration_role(collaboration_id, new_role):
	client = get_box_client()
	url = f"https://api.box.com/2.0/collaborations/{collaboration_id}"
	payload = {
		"role": new_role
	}
	response = client.session.put(url, json=payload)
	if response.status_code in [200,201]:
		print(f"Collaboration {collaboration_id} updated to role {new_role}")
	else:
		print(f"[ERROR] Failed to update collaboration: {response.status_code} {response.text}")
		
def create_upload_folder(folder_name):
	client = get_box_client()
	try:
		new_folder = client.folder("0").create_subfolder(folder_name)
		print(f"[BOX] Created folder '{folder_name}' with ID {new_folder.id}")
		return new_folder.id
	except Exception as e:
		print(f"[ERROR] Failed to create folder: {e}")
		return none
