import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
import torch
import cv2
import glob
import time
import traceback
import sys
from dotenv import load_dotenv

# Load environment variables from .env file
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
load_dotenv(os.path.join(project_root, '.env'))

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.seat_occupancy_detector import SeatOccupancyDetector


def get_all_images(folder_path: str) -> list[str]:
    """Get all image files from the specified folder

    Args:
        folder_path (str): Path to the folder containing images

    Returns:
        list[str]: List of image file paths
    """
    image_patterns = ['*.jpg', '*.jpeg', '*.png', '*.bmp', "*.HEIC"]
    image_files = []
    for pattern in image_patterns:
        search_path = os.path.join(folder_path, pattern)
        found_files_list = glob.glob(search_path)
        image_files.extend(found_files_list)
    return sorted(image_files)


def get_all_videos(folder_path: str) -> list[str]:
    """Get all video files from the specified folder

    Args:
        folder_path (str): Path to the folder containing videos

    Returns:
        list[str]: List of video file paths
    """
    video_patterns = ['*.mp4', '*.avi', '*.mov', '*.mkv']
    video_files = []
    for pattern in video_patterns:
        search_path = os.path.join(folder_path, pattern)
        found_files_list = glob.glob(search_path)
        video_files.extend(found_files_list)
    return sorted(video_files)


def prepare_test_frame(frame: cv2.typing.MatLike) -> cv2.typing.MatLike:
    """Resize small test inputs before inference while preserving aspect ratio.

    This is a test-time only helper for small-target scenes. It avoids stretching
    the image and only upsamples when the shorter side is below the configured
    minimum.
    """
    if not ENABLE_TEST_UPSCALE:
        return frame

    height, width = frame.shape[:2]
    short_side = min(height, width)

    if short_side >= MIN_TEST_IMAGE_SIDE:
        return frame

    scale = MIN_TEST_IMAGE_SIDE / short_side
    new_width = int(round(width * scale))
    new_height = int(round(height * scale))

    interpolation = cv2.INTER_CUBIC if scale > 1.0 else cv2.INTER_AREA
    return cv2.resize(frame, (new_width, new_height), interpolation=interpolation)


def test_images_dual_model(
    image_files: list[str], 
    occupancy_model_path: str,
    seat_model_path: str,
    person_class_id: int,
    hogging_item_class_id: list,
    seat_class_id: list,
    result_folder: str,
    model_name: str
) -> None:
    """Test dual model (occupancy + seat) on images

    Args:
        image_files (list[str]): List of image file paths
        occupancy_model_path (str): Path to occupancy detection model
        seat_model_path (str): Path to seat detection model
        person_class_id (int): Class ID for person
        hogging_item_class_id (list): List of class IDs for hogging items
        seat_class_id (list): List of class IDs for seats
        result_folder (str): Folder to save results
        model_name (str): Name of the model being tested
    """
    detector = SeatOccupancyDetector(
        occupancy_model_path=occupancy_model_path,
        seat_model_path=seat_model_path,
        debug_mode=DEBUG_MODE,
        device=DEVICE
    )
    
    for idx, image_path in enumerate(image_files, 1):
        base_name = os.path.basename(image_path)
        image = cv2.imread(image_path)
        
        if image is None:
            print(f"Warning: Failed to load image {image_path}")
            continue

        prepared_image = prepare_test_frame(image)
        
        output_path = os.path.join(result_folder, base_name)
        
        result = detector.get_occupancy_stats_with_seats(
            prepared_image,
            person_class_id=person_class_id,
            hogging_item_class_id=hogging_item_class_id,
            seat_class_id=seat_class_id, 
            proximity_threshold=PROXIMITY_THRESHOLD,
            item_cluster_threshold=ITEM_CLUSTER_THRESHOLD,
            confidence_threshold=CONFIDENCE_THRESHOLD,
            person_confidence_threshold=PERSON_CONFIDENCE_THRESHOLD,
            item_confidence_threshold=ITEM_CONFIDENCE_THRESHOLD,
            seat_confidence_threshold=SEAT_CONFIDENCE_THRESHOLD,
            seat_expansion_factor=SEAT_EXPANSION_FACTOR, 
            use_preprocessing=USE_PREPROCESSING,
            visualize=VISUALIZE_RESULTS,
            output_path=output_path,
            imgsz=IMAGE_SIZE,
            seat_imgsz=SEAT_IMAGE_SIZE,
            location="main_library", 
            area="3/F Old Wing"
        )
        
        # Extract stats from result (result is now a dict with 'stats' and 'visualized_image')
        stats = result['stats'] if isinstance(result, dict) and 'stats' in result else result
        print(f"[{model_name}] Image {idx}/{len(image_files)}: {stats}")


def test_videos_dual_model(
    video_files: list[str],
    occupancy_model_path: str,
    seat_model_path: str,
    person_class_id: int,
    hogging_item_class_id: list,
    seat_class_id: list,
    result_folder: str,
    model_name: str
) -> None:
    """Test dual model (occupancy + seat) on videos

    Args:
        video_files (list[str]): List of video file paths
        occupancy_model_path (str): Path to occupancy detection model
        seat_model_path (str): Path to seat detection model
        person_class_id (int): Class ID for person
        hogging_item_class_id (list): List of class IDs for hogging items
        seat_class_id (list): List of class IDs for seats
        result_folder (str): Folder to save results
        model_name (str): Name of the model being tested
    """
    detector = SeatOccupancyDetector(
        occupancy_model_path=occupancy_model_path,
        seat_model_path=seat_model_path,
        debug_mode=DEBUG_MODE,
        device=DEVICE
    )
    
    for video_idx, video_path in enumerate(video_files, 1):
        base_name = os.path.splitext(os.path.basename(video_path))[0]
        output_video_path = os.path.join(result_folder, f"{base_name}_annotated.mp4")
        
        print(f"\n[{model_name}] Processing video {video_idx}/{len(video_files)}: {base_name}")
        
        # Open video
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print(f"Error: Cannot open video {video_path}")
            continue
        
        # Get video properties
        fps = int(cap.get(cv2.CAP_PROP_FPS))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        print(f"  Video info: {width}x{height}, {fps} FPS, {total_frames} frames")
        
        # Create video writer
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_video_path, fourcc, fps, (width, height))
        
        frame_count = 0
        start_time = time.time()
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            
            frame_count += 1
            prepared_frame = prepare_test_frame(frame)
            
            # Process frame with detector (no output_path to avoid disk I/O)
            result = detector.get_occupancy_stats_with_seats(
                prepared_frame,
                person_class_id=person_class_id,
                hogging_item_class_id=hogging_item_class_id,
                seat_class_id=seat_class_id,
                proximity_threshold=PROXIMITY_THRESHOLD,
                item_cluster_threshold=ITEM_CLUSTER_THRESHOLD,
                confidence_threshold=CONFIDENCE_THRESHOLD,
                person_confidence_threshold=PERSON_CONFIDENCE_THRESHOLD,
                item_confidence_threshold=ITEM_CONFIDENCE_THRESHOLD,
                seat_confidence_threshold=SEAT_CONFIDENCE_THRESHOLD,
                seat_expansion_factor=SEAT_EXPANSION_FACTOR,
                use_preprocessing=USE_PREPROCESSING,
                visualize=VISUALIZE_RESULTS,
                output_path="", 
                imgsz=IMAGE_SIZE,
                seat_imgsz=SEAT_IMAGE_SIZE,
                location="main_library",
                area="3/F Old Wing"
            )
            
            # Write the annotated frame directly to video when visualization is enabled.
            # Otherwise keep the original frame so timing stays close to inference-only mode.
            if 'visualized_image' in result:
                out.write(result['visualized_image'])
            else:
                out.write(frame)
            
            # Progress update
            if frame_count % 30 == 0 or frame_count == total_frames:
                elapsed = time.time() - start_time
                progress = (frame_count / total_frames) * 100 if total_frames > 0 else 0
                processing_fps = frame_count / elapsed if elapsed > 0 else 0
                print(f"  Progress: {frame_count}/{total_frames} ({progress:.1f}%) - {processing_fps:.1f} FPS")
        
        cap.release()
        out.release()
        
        elapsed_time = time.time() - start_time
        avg_fps = frame_count / elapsed_time if elapsed_time > 0 else 0
        print(f"  Completed: {frame_count} frames in {elapsed_time:.2f}s (avg {avg_fps:.2f} FPS)")
        print(f"  Output saved: {output_video_path}")


    
if __name__ == "__main__":
    """
    Unified testing script for both images and videos
    - Tests Standard Model (YOLO11l) and Self-Trained Model
    - Supports both image and video inputs
    """

    # ==================== Global Configuration ====================
    test_dir = os.path.dirname(os.path.abspath(__file__))
    computer_vision_dir = os.path.dirname(test_dir)
    
    # Shared parameters (loaded from .env)
    PROXIMITY_THRESHOLD = float(os.getenv('PROXIMITY_THRESHOLD', '150.0'))
    ITEM_CLUSTER_THRESHOLD = float(os.getenv('ITEM_CLUSTER_THRESHOLD', '70.0'))
    SEAT_EXPANSION_FACTOR = int(os.getenv('SEAT_EXPANSION_FACTOR', '3'))
    IMAGE_SIZE = int(os.getenv('IMAGE_SIZE', '960'))
    SEAT_IMAGE_SIZE = int(os.getenv('SEAT_IMAGE_SIZE', str(IMAGE_SIZE)))
    CONFIDENCE_THRESHOLD = float(os.getenv('CONFIDENCE_THRESHOLD', '0.2'))
    PERSON_CONFIDENCE_THRESHOLD = float(os.getenv('PERSON_CONFIDENCE_THRESHOLD', str(CONFIDENCE_THRESHOLD)))
    ITEM_CONFIDENCE_THRESHOLD = float(os.getenv('ITEM_CONFIDENCE_THRESHOLD', str(CONFIDENCE_THRESHOLD)))
    SEAT_CONFIDENCE_THRESHOLD = float(os.getenv('SEAT_CONFIDENCE_THRESHOLD', str(CONFIDENCE_THRESHOLD)))
    USE_PREPROCESSING = os.getenv('USE_PREPROCESSING', 'False').lower() == 'true'
    VISUALIZE_RESULTS = os.getenv('VISUALIZE_RESULTS', 'False').lower() == 'true'
    ENABLE_TEST_UPSCALE = os.getenv('ENABLE_TEST_UPSCALE', 'True').lower() == 'true'
    MIN_TEST_IMAGE_SIDE = int(os.getenv('MIN_TEST_IMAGE_SIDE', '900'))
    DEBUG_MODE = os.getenv('DEBUG_MODE', 'False').lower() == 'true'
    DEVICE = os.getenv('DEVICE', 'cuda')
    
    # Model paths (loaded from .env)
    standard_occupancy_model = os.path.join(computer_vision_dir, os.getenv('STANDARD_OCCUPANCY_MODEL_PATH', 'train_models/yolo11l.pt'))
    standard_seat_model = os.path.join(computer_vision_dir, os.getenv('STANDARD_SEAT_MODEL_PATH', 'train_models/yolo11l.pt'))
    custom_occupancy_model = os.path.join(computer_vision_dir, os.getenv('CUSTOM_OCCUPANCY_MODEL_PATH', 'models/mixed/model_v2/best.pt'))
    custom_seat_model = os.path.join(computer_vision_dir, os.getenv('CUSTOM_SEAT_MODEL_PATH', 'models/mixed/model_v2/best.pt'))
    
    # Class IDs (loaded from .env)
    STANDARD_PERSON_CLASS_ID = int(os.getenv('STANDARD_PERSON_CLASS_ID', '0'))
    STANDARD_HOGGING_ITEM_CLASS_ID = [int(x.strip()) for x in os.getenv('STANDARD_HOGGING_ITEM_CLASS_ID', '24,25,26,39,41,63,64,66,67,73,76').split(',')]
    STANDARD_SEAT_CLASS_ID = [int(x.strip()) for x in os.getenv('STANDARD_SEAT_CLASS_ID', '56,57').split(',')]
    CUSTOM_PERSON_CLASS_ID = int(os.getenv('CUSTOM_PERSON_CLASS_ID', '15'))
    CUSTOM_HOGGING_ITEM_CLASS_ID = [int(x.strip()) for x in os.getenv('CUSTOM_HOGGING_ITEM_CLASS_ID', '0,1,2,3,4,6,7,8,9,10,11,12,13,14,16,17,18').split(',')]
    CUSTOM_SEAT_CLASS_ID = [int(x.strip()) for x in os.getenv('CUSTOM_SEAT_CLASS_ID', '5').split(',')]
    
    # Print header
    print("=" * 80)
    print("Seat Occupancy Detector - Unified Testing (Images + Videos)")
    print("=" * 80)
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    print(f"IMAGE_SIZE: {IMAGE_SIZE}")
    print(f"SEAT_IMAGE_SIZE: {SEAT_IMAGE_SIZE}")
    print(f"PERSON_CONFIDENCE_THRESHOLD: {PERSON_CONFIDENCE_THRESHOLD}")
    print(f"ITEM_CONFIDENCE_THRESHOLD: {ITEM_CONFIDENCE_THRESHOLD}")
    print(f"SEAT_CONFIDENCE_THRESHOLD: {SEAT_CONFIDENCE_THRESHOLD}")
    print(f"USE_PREPROCESSING: {USE_PREPROCESSING}")
    print(f"VISUALIZE_RESULTS: {VISUALIZE_RESULTS}")
    print(f"ENABLE_TEST_UPSCALE: {ENABLE_TEST_UPSCALE}")
    print(f"MIN_TEST_IMAGE_SIDE: {MIN_TEST_IMAGE_SIDE}")
    if torch.cuda.is_available():
        print(f"CUDA version: {torch.version.cuda}")

    try:
        # ==================== PART 1: IMAGE TESTING ====================
        print("\n" + "=" * 80)
        print("PART 1: IMAGE TESTING")
        print("=" * 80)
        
        # Get all images
        image_folder_name = os.getenv('IMAGE_DATA_FOLDER', 'chi_wah')
        image_data_folder = os.path.join(test_dir, 'data', image_folder_name)
        image_files = get_all_images(image_data_folder)
        
        if len(image_files) == 0:
            print(f"Warning: No images found in '{image_data_folder}'")
        else:
            print(f"Found {len(image_files)} test images\n")
            
            # --- Test 1: Standard YOLO Model ---
            print("\n" + "-" * 80)
            print("Test 1: Standard YOLO Model (yolo11l.pt)")
            print("-" * 80)
            
            standard_result_folder = os.path.join(test_dir, "standard_model_results")
            os.makedirs(standard_result_folder, exist_ok=True)
            
            start_time = time.time()
            print(f"Start time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
            
            test_images_dual_model(
                image_files=image_files,
                occupancy_model_path=standard_occupancy_model,
                seat_model_path=standard_seat_model,
                person_class_id=STANDARD_PERSON_CLASS_ID,
                hogging_item_class_id=STANDARD_HOGGING_ITEM_CLASS_ID,
                seat_class_id=STANDARD_SEAT_CLASS_ID,
                result_folder=standard_result_folder,
                model_name="Standard Model"
            )
            
            elapsed = time.time() - start_time
            print(f"\nFinished time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"Total duration: {elapsed:.2f}s")
            print(f"Average time per image: {elapsed/len(image_files):.3f}s")
            print(f"FPS: {len(image_files)/elapsed:.2f}")
            
            # --- Test 2: Self-Trained Model ---
            print("\n" + "-" * 80)
            print("Test 2: Self-Trained Model (custom weights)")
            print("-" * 80)
            
            custom_result_folder = os.path.join(test_dir, "self-trained_model_results")
            os.makedirs(custom_result_folder, exist_ok=True)
            
            if not os.path.exists(custom_occupancy_model):
                raise FileNotFoundError(f"Self-trained occupancy model not found: {custom_occupancy_model}")
            if not os.path.exists(custom_seat_model):
                raise FileNotFoundError(f"Self-trained seat model not found: {custom_seat_model}")
            
            start_time = time.time()
            print(f"Start time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
            
            test_images_dual_model(
                image_files=image_files,
                occupancy_model_path=custom_occupancy_model,
                seat_model_path=custom_seat_model,
                person_class_id=CUSTOM_PERSON_CLASS_ID,
                hogging_item_class_id=CUSTOM_HOGGING_ITEM_CLASS_ID,
                seat_class_id=CUSTOM_SEAT_CLASS_ID,
                result_folder=custom_result_folder,
                model_name="Self-Trained Model"
            )
            
            elapsed = time.time() - start_time
            print(f"\nFinished time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"Total duration: {elapsed:.2f}s")
            print(f"Average time per image: {elapsed/len(image_files):.3f}s")
            print(f"FPS: {len(image_files)/elapsed:.2f}")
        
        # ==================== PART 2: VIDEO TESTING ====================
        print("\n" + "=" * 80)
        print("PART 2: VIDEO TESTING")
        print("=" * 80)
        
        # Get all videos
        video_folder_name = os.getenv('VIDEO_DATA_FOLDER', 'main_lib')
        video_data_folder = os.path.join(test_dir, 'data', video_folder_name)
        video_files = get_all_videos(video_data_folder)
        
        if len(video_files) == 0:
            print(f"No videos found in '{video_data_folder}' - Skipping video testing")
        else:
            print(f"Found {len(video_files)} test videos\n")
            
            # --- Test 3: Standard Model on Videos ---
            print("\n" + "-" * 80)
            print("Test 3: Standard YOLO Model - Video Processing")
            print("-" * 80)
            
            standard_video_result_folder = os.path.join(test_dir, "standard_model_video_results")
            os.makedirs(standard_video_result_folder, exist_ok=True)
            
            test_videos_dual_model(
                video_files=video_files,
                occupancy_model_path=standard_occupancy_model,
                seat_model_path=standard_seat_model,
                person_class_id=STANDARD_PERSON_CLASS_ID,
                hogging_item_class_id=STANDARD_HOGGING_ITEM_CLASS_ID,
                seat_class_id=STANDARD_SEAT_CLASS_ID,
                result_folder=standard_video_result_folder,
                model_name="Standard Model (Video)"
            )
            
            # --- Test 4: Self-Trained Model on Videos ---
            print("\n" + "-" * 80)
            print("Test 4: Self-Trained Model - Video Processing")
            print("-" * 80)
            
            custom_video_result_folder = os.path.join(test_dir, "self-trained_model_video_results")
            os.makedirs(custom_video_result_folder, exist_ok=True)
            
            test_videos_dual_model(
                video_files=video_files,
                occupancy_model_path=custom_occupancy_model,
                seat_model_path=custom_seat_model,
                person_class_id=CUSTOM_PERSON_CLASS_ID,
                hogging_item_class_id=CUSTOM_HOGGING_ITEM_CLASS_ID,
                seat_class_id=CUSTOM_SEAT_CLASS_ID,
                result_folder=custom_video_result_folder,
                model_name="Self-Trained Model (Video)"
            )
        
        # ==================== COMPLETION ====================
        print("\n" + "=" * 80)
        print("ALL TESTS COMPLETED SUCCESSFULLY")
        print("=" * 80)
        input("\nPress Enter to exit...")
            
    except FileNotFoundError as e:
        print(f"\nFile Not Found Error: {str(e)}")
        print("Please ensure your model paths are correct!")
    except Exception as e:
        print(f"\nError occurred: {str(e)}")
        traceback.print_exc()
        print("\nPlease check your configuration parameters")
