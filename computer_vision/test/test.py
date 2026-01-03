import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
import torch
import cv2
import glob
import time
import traceback
import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.seat_occupancy_detector import SeatOccupancyDetector
import time


def get_all_image() -> list[str]:
    """Get all image files from the test folder

    Returns:
        list[str]: List of image file paths
    """
    image_patterns = ['*.jpg', '*.jpeg', '*.png', '*.bmp', "*.HEIC"]
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
        output_path_seat = os.path.join(RESULT_FOLDER_SEATS, base_name)
        detector.count_total_seats(
            image,
            seat_class_id=seat_class_id,
            confidence_threshold=CONFIDENCE_THRESHOLD,
            visualize=True,
            output_path=output_path_seat,
            imgsz=IMAGE_SIZE
        )
        
        # Call Occupancy model 
        image_adv = image.copy() 
        output_path_adv = os.path.join(RESULT_FOLDER_OCCUPANCY, base_name)
        
        result = detector.get_occupancy_stats_with_seats(
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
            seat_imgsz=SEAT_IMAGE_SIZE,
            location="main_library", 
            area="3/F Old Wing"
        )
        print(result)

    
if __name__ == "__main__":
    """
    Self-training model vs Standard model testing script
    """

    # Initialize all shared and global parameters
    SEAT_MODEL_PATH = "../yolo11l.pt" 
    TEST_FOLDER = "data"
    RESULT_FOLDER_OCCUPANCY = "standard_model_results"
    RESULT_FOLDER_SEATS = "standard_model_seats_results"
    
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
                67, # cell phone
                73, # book 
                76  # scissors
            ]
            SEAT_CLASS_ID = [56, 57]         # chair and couch
            OCCUPANCY_MODEL_PATH = "../yolo11l.pt"
            test_model(image_files, PERSON_CLASS_ID, HOGGING_ITEM_CLASS_ID, SEAT_CLASS_ID)

            print("\n" + "=" * 80)
            print("Finished Standard YOLO Model Testing")
            print("=" * 80)
            input("\nPress Enter to continue to self-trained model testing...")

            RESULT_FOLDER_OCCUPANCY = "self-trained_model_results"
            RESULT_FOLDER_SEATS = "self-trained_model_seats_results"
            os.makedirs(RESULT_FOLDER_OCCUPANCY, exist_ok=True)
            os.makedirs(RESULT_FOLDER_SEATS, exist_ok=True)
            
            # Testing the self-trained model
            # v1: 30, v2:23
            PERSON_CLASS_ID = 23
            # v1: 0-29, v2: 0-22
            HOGGING_ITEM_CLASS_ID = list(range(23)) # hogging_item
            SEAT_CLASS_ID = [56, 57]         # seat and sofa
            # SEAT_MODEL_PATH = os.path.join("..", "models", "chair_and_sofa", "best.pt")
            OCCUPANCY_MODEL_PATH = os.path.join("..", "models", "person_and_item", "v2", "best.pt")
            if not os.path.exists(OCCUPANCY_MODEL_PATH):
                raise FileNotFoundError(f"Self-trained model not found at path: {OCCUPANCY_MODEL_PATH}")
            print("\n" + "=" * 80)
            print("Testing Self-Trained Model")
            print("=" * 80)
            current_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
            print("Start Time:", current_time)
            test_model(image_files, PERSON_CLASS_ID, HOGGING_ITEM_CLASS_ID, SEAT_CLASS_ID)
            finished_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
            print("Finished Time:", finished_time)
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