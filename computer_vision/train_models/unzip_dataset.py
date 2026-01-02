import zipfile
import os
from pathlib import Path
import shutil

# =================Configuration Area=================
# Assume you have uploaded the zip file to the yolov11_project directory
# Use $HOME environment variable to ensure the path is correct
HOME_DIR = os.getenv("HOME") 
ZIP_FILE_NAME = "person_and_item_dataset.zip"

# Source file path
ZIP_PATH = os.path.join(HOME_DIR, ZIP_FILE_NAME)

# Extraction target path (will automatically create a new folder to avoid scattered files)
EXTRACT_TO = os.path.join(HOME_DIR, "fyp", "person_and_item", "dataset")
# ====================================================

def unzip_file():
    # 1. Check if the file exists
    if not os.path.exists(ZIP_PATH):
        print(f"Error: Cannot find file: {ZIP_PATH}")
        print(" Please confirm that you have uploaded the zip file to the correct location using scp.")
        return

    # 2. Create target directory
    if not os.path.exists(EXTRACT_TO):
        os.makedirs(EXTRACT_TO)
        print(f"Created directory: {EXTRACT_TO}")
    else:
        print(f"Target directory already exists: {EXTRACT_TO}")

    print(f"Starting to unzip {ZIP_FILE_NAME} ...")
    print(" This may take a few seconds to a few minutes, please be patient...")

    try:
        # 3. Start unzipping
        with zipfile.ZipFile(ZIP_PATH, 'r') as zip_ref:
            # Get the list of files to show progress (simple)
            file_list = zip_ref.namelist()
            total_files = len(file_list)
            print(f"   Total {total_files} files in the zip archive")
            
            zip_ref.extractall(EXTRACT_TO)
            
        print("\n" + "="*40)
        print("Unzip successful!")
        print("="*40)
        print(f"Dataset located at: {EXTRACT_TO}")
        
        # 4. Check data.yaml (usually present in YOLO dataset packages)
        yaml_path = os.path.join(EXTRACT_TO, "data.yaml")
        if os.path.exists(yaml_path):
            print(f"Found configuration file: {yaml_path}")
            print("Important: Please remember to modify 'path' in data.yaml to the absolute path on the server!")
        else:
            print("Warning: data.yaml not found directly in the extraction directory, please check subfolders.")

    except zipfile.BadZipFile:
        print("Error: File is corrupted and cannot be read. Please re-upload.")
    except Exception as e:
        print(f"An unknown error occurred: {e}")

if __name__ == "__main__":
    unzip_file()
