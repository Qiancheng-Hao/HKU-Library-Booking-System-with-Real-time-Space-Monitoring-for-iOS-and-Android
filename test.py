import cv2
import os
import glob
import time
import torch
import traceback
import sys
from seat_occupancy_detector import SeatOccupancyDetector


def get_all_image() -> list[str]:
    """Get all image files from the test folder

    Returns:
        list[str]: List of image file paths
    """
    image_patterns = ['*.jpg', '*.jpeg', '*.png', '*.bmp']
    image_files = []
    for pattern in image_patterns:
        # create the full search path
        search_path = os.path.join(TEST_FOLDER, pattern)
        
        # glob for files matching the pattern
        found_files_list = glob.glob(search_path)
        
        # Add found files to the list
        image_files.extend(found_files_list)
    return image_files 


def test_model(image_files: list[str], person_class_id, hogging_item_class_id, seat_class_id) -> None:
    """_summary_

    Args:
        image_files (list[str]): _description_
        person_class_id (_type_): _description_
        hogging_item_class_id (_type_): _description_
        seat_class_id (_type_): _description_
    """
    detector = SeatOccupancyDetector(
        occupancy_model_path=OCCUPANCY_MODEL_PATH,
        seat_model_path=SEAT_MODEL_PATH,
        debug_mode=DEBUG_MODE,
        device=DEVICE
    )
    
    for idx, image_path in enumerate(image_files, 1):
        base_name = os.path.basename(image_path) # get the image name
        image = cv2.imread(image_path)  # load the image and change to np.ndarray format
        
        # Call seat counting function
        start_time_seat = time.time()
        output_path_seat = os.path.join(RESULT_FOLDER_SEATS, base_name)
        stats_seat = detector.count_total_seats(
            image,
            seat_class_id=seat_class_id,
            confidence_threshold=CONFIDENCE_THRESHOLD,
            visualize=True,
            output_path=output_path_seat,
            imgsz=IMAGE_SIZE
        )
        
        # Call Occupancy model 
        start_time_adv = time.time()
        image_adv = image.copy() 
        output_path_adv = os.path.join(RESULT_FOLDER_OCCUPANCY, base_name)
        
        stats_adv = detector.get_occupancy_stats_with_seats(
            image_adv,
            person_class_id=person_class_id,
            hogging_item_class_id=hogging_item_class_id,
            seat_class_id=seat_class_id, 
            proximity_threshold=PROXIMITY_THRESHOLD,
            item_cluster_threshold=ITEM_CLUSTER_THRESHOLD,
            confidence_threshold=CONFIDENCE_THRESHOLD,
            seat_expansion_factor=SEAT_EXPANSION_FACTOR, 
            visualize=True,
            output_path=output_path_adv,
            imgsz=IMAGE_SIZE,
            seat_imgsz=SEAT_IMAGE_SIZE 
        )

    
if __name__ == "__main__":
    """
    Self-training model vs Standard model testing script
    """

    # Initialize all shared and global parameters
    SEAT_MODEL_PATH = "yolo11l.pt" 
    TEST_FOLDER = "Test"
    RESULT_FOLDER_OCCUPANCY = "Result_Occupancy"
    RESULT_FOLDER_SEATS = "Result_Seats"
    
    PROXIMITY_THRESHOLD = 150.0  # Distance for person-item association
    ITEM_CLUSTER_THRESHOLD = 70.0 # Distance for item-item clustering
    SEAT_EXPANSION_FACTOR = 3   # Factor to expand seat bbox (2 = 100% larger)
    
    IMAGE_SIZE = 640
    SEAT_IMAGE_SIZE = 640 
    CONFIDENCE_THRESHOLD = 0.4 
    DEBUG_MODE = False
    DEVICE = 'auto' 
    
    # Ensure result folders exist
    os.makedirs(RESULT_FOLDER_OCCUPANCY, exist_ok=True)
    os.makedirs(RESULT_FOLDER_SEATS, exist_ok=True)
    
    # Print header
    print("=" * 80)
    print("Seat Occupancy Detector Testing")
    print("=" * 80)
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"CUDA version: {torch.version.cuda}")

    try:
        # Get all image files in the test folder
        image_files = get_all_image()
        
        # Check if any images found
        if len(image_files) == 0:
            print(f"\n Error: No image files found in '{TEST_FOLDER}' folder!")
        else:
            image_files.sort()
            print(f"\n Found {len(image_files)} test images")
            
            # Testing the standard model first
            print("\n" + "=" * 80)
            print("Testing Standard YOLO Model")
            print("=" * 80)
            PERSON_CLASS_ID = 0
            HOGGING_ITEM_CLASS_ID = [
                24, # backpack
                25, # umbrella
                26, # handbag
                39, # bottle
                41, # cup
                63, # laptop
                64, # mouse
                66, # keyboard
                67, # Phone
                73, # book 
                76  # scissors
            ]
            SEAT_CLASS_ID = [56, 57]         # chair and sofa
            OCCUPANCY_MODEL_PATH = "yolo11l.pt"
            test_model(image_files, PERSON_CLASS_ID, HOGGING_ITEM_CLASS_ID, SEAT_CLASS_ID)

            print("\n" + "=" * 80)
            print("Finished Standard YOLO Model Testing")
            print("=" * 80)
            
            # wait for user input before testing self-trained model
            input("\nPress Enter to continue to self-trained model testing...")

            # Testing the self-trained model
            PERSON_CLASS_ID = 30
            HOGGING_ITEM_CLASS_ID = list(range(30)) # hogging_item
            SEAT_CLASS_ID = [56, 57]         # seat and sofa
            SEAT_MODEL_PATH = os.path.join("models", "chair_and_sofa", "best.pt")
            OCCUPANCY_MODEL_PATH = os.path.join("models", "person_and_item", "best.pt")
            if not os.path.exists(OCCUPANCY_MODEL_PATH):
                raise FileNotFoundError(f"Self-trained model not found at path: {OCCUPANCY_MODEL_PATH}")
            print("\n" + "=" * 80)
            print("Testing Self-Trained Model")
            print("=" * 80)
            test_model(image_files, PERSON_CLASS_ID, HOGGING_ITEM_CLASS_ID, SEAT_CLASS_ID)
            
            # wait for user input before exiting
            print("\n" + "=" * 80)
            print("Finished Self-Trained Model Testing")
            print("=" * 80)
            input("\nPress Enter to exit...")
            
    except FileNotFoundError as e:
        print(f"\nFile Not Found Error: {str(e)}")
        print("Please ensure your model paths (OCCUPANCY_MODEL_PATH, SEAT_MODEL_PATH) are correct!")
        print("Ensure class IDs match")
    except Exception as e:
        print(f"\n Error Happened: {str(e)}")
        traceback.print_exc()
        print("\nPlease check your configuration parameters (especially if Class ID is correct)")