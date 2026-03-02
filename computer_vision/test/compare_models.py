"""
Compare Standard YOLO11l vs Custom Trained Models
"""
import os
import sys
import cv2
from ultralytics import YOLO

# Add parent directory to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Paths
computer_vision_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
custom_occupancy_model_path = os.path.join(computer_vision_dir, "models", "person_and_item", "v4", "best.pt")
custom_seat_model_path = os.path.join(computer_vision_dir, "models", "chair_and_sofa", "v3", "best.pt")
standard_model_path = os.path.join(computer_vision_dir, "train_models", "yolo11l.pt")

print("=" * 80)
print("STANDARD vs CUSTOM MODEL COMPARISON")
print("=" * 80)

# Find test image
test_dir = os.path.dirname(os.path.abspath(__file__))
test_image_folder = os.path.join(test_dir, 'data', 'chi_wah')
if not os.path.exists(test_image_folder):
    test_image_folder = os.path.join(test_dir, 'data', 'ChiWah')

import glob
images = glob.glob(os.path.join(test_image_folder, '*.jpg')) + \
         glob.glob(os.path.join(test_image_folder, '*.png'))
test_image = images[0]
print(f"\nTest image: {os.path.basename(test_image)}")

image = cv2.imread(test_image)
print(f"Image shape: {image.shape}")

# Load models
print("\nLoading models...")
custom_occupancy = YOLO(custom_occupancy_model_path)
custom_seat = YOLO(custom_seat_model_path)
standard = YOLO(standard_model_path)
print("✓ All models loaded")

# Test with different confidence thresholds
conf_thresholds = [0.01, 0.05, 0.1, 0.2, 0.3, 0.5]

print("\n" + "=" * 80)
print("STANDARD YOLO11L MODEL")
print("=" * 80)
for conf in conf_thresholds:
    results = standard(image, conf=conf, imgsz=640, verbose=False)
    detections = len(results[0].boxes)
    print(f"Confidence {conf:.2f}: {detections:3d} detections", end="")
    if detections > 0 and conf <= 0.1:
        print(" - Classes detected:", end="")
        detected_classes = set()
        for box in results[0].boxes:
            cls_id = int(box.cls[0])
            detected_classes.add(standard.names[cls_id])
        print(f" {', '.join(list(detected_classes)[:5])}")
    else:
        print()

print("\n" + "=" * 80)
print("CUSTOM OCCUPANCY MODEL (person + items)")
print("=" * 80)
for conf in conf_thresholds:
    results = custom_occupancy(image, conf=conf, imgsz=640, verbose=False)
    detections = len(results[0].boxes)
    print(f"Confidence {conf:.2f}: {detections:3d} detections", end="")
    if detections > 0 and conf <= 0.1:
        print(" - Classes detected:", end="")
        detected_classes = set()
        for box in results[0].boxes:
            cls_id = int(box.cls[0])
            detected_classes.add(custom_occupancy.names[cls_id])
        print(f" {', '.join(list(detected_classes)[:5])}")
    else:
        print()

print("\n" + "=" * 80)
print("CUSTOM SEAT MODEL (chair + sofa)")
print("=" * 80)
for conf in conf_thresholds:
    results = custom_seat(image, conf=conf, imgsz=640, verbose=False)
    detections = len(results[0].boxes)
    print(f"Confidence {conf:.2f}: {detections:3d} detections", end="")
    if detections > 0 and conf <= 0.1:
        print(" - Classes detected:", end="")
        detected_classes = set()
        for box in results[0].boxes:
            cls_id = int(box.cls[0])
            detected_classes.add(custom_seat.names[cls_id])
        print(f" {', '.join(list(detected_classes)[:5])}")
    else:
        print()

print("\n" + "=" * 80)
print("DIAGNOSIS")
print("=" * 80)

# Run final test
std_results = standard(image, conf=0.1, imgsz=640, verbose=False)
custom_occ_results = custom_occupancy(image, conf=0.1, imgsz=640, verbose=False)
custom_seat_results = custom_seat(image, conf=0.1, imgsz=640, verbose=False)

std_count = len(std_results[0].boxes)
custom_count = len(custom_occ_results[0].boxes) + len(custom_seat_results[0].boxes)

if std_count > 0 and custom_count == 0:
    print("\n❌ CONFIRMED: Custom models are severely overfitted")
    print("   Standard model can detect objects, but custom models cannot")
    print("\n   ROOT CAUSE:")
    print("   - Training images are from different scenes/angles than test images")
    print("   - Model memorized training scene features instead of generalizing")
    print("\n   SOLUTIONS:")
    print("   1. Collect training data from the SAME locations as test images")
    print("   2. Include more diverse angles, lighting, and times of day")
    print("   3. Use standard model for now, only train custom classes (iPad, etc)")
elif std_count == 0 and custom_count == 0:
    print("\n⚠ Both models failed - this test image might be unusual")
    print("   Try testing with more images from different scenes")
elif custom_count > 0:
    print(f"\n✓ Custom models ARE working!")
    print(f"   Standard: {std_count} detections")
    print(f"   Custom: {custom_count} detections")
    print("   The issue might be with specific test images or confidence threshold")

print("\n" + "=" * 80)
