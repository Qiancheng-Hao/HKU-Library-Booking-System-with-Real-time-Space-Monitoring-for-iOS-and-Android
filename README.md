# HKU Library Booking System with Real-time Space Monitoring

## Overview

This project implements a computer vision-based library seat occupancy detection system. Using YOLO object detection models, the system can:
- Detect library seat occupancy (both people and items hogging seats)
- Count total seats and available seats
- Distinguish between valid occupancy and hogging behavior (items without people)

## Computer Vision Module

### Core Features

1. **Seat Occupancy Detection**: Dual-model architecture
   - **Occupancy Model**: Detects people and items (backpacks, laptops, books, etc.)
   - **Seat Model**: Detects seat positions (chairs and sofas)

2. **Intelligent Occupancy Logic**:
   - Detected people are directly counted as occupied
   - Items are clustered and checked if they are on seats
   - Items associated with people are filtered (no double counting)
   - Items off seats are ignored

3. **Visualization Output**:
   - Green boxes: People (occupied)
   - Red boxes: Hogging items (counted as occupied)
   - Blue boxes: Items with people (not separately counted)
   - Yellow boxes: Items off seats (ignored)
   - Cyan boxes: Seat positions (reference)

### Project Structure

```
computer_vision/
├── seat_occupancy_detector.py  # Core detector class
├── test.py                      # Testing script
├── train_person_and_item.py    # Train person & item detection model
├── train_seat_model.py         # Train seat detection model
├── yolo11l.pt                   # YOLO base pretrained model
├── Models/
│   ├── chair_and_sofa/
│   │   └── best.pt             # Seat detection model
│   └── person_and_item/
│       └── best.pt             # Person & item detection model
└── Test/                        # Test images folder
```

---

## Installation

### 1. Install OpenCV

Install OpenCV using conda:

```bash
conda install -c conda-forge opencv
```

### 2. Install PyTorch (CUDA 12.6 support)

```bash
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu126
```

**Note**: If your system doesn't support CUDA, use the CPU version:

```bash
pip3 install torch torchvision
```

### 3. Install Ultralytics YOLO

```bash
pip install ultralytics
```

### Dependency Check

Ensure the following libraries are successfully installed:
- `opencv-python` or `opencv-contrib-python`
- `torch` >= 2.0
- `ultralytics` >= 8.0
- `numpy`

---

## Running Tests

### 1. Prepare Test Images

Place test images in the `computer_vision/Test/` folder. Supported formats:
- `.jpg`
- `.jpeg`
- `.png`
- `.bmp`

### 2. Run Test Script

Navigate to the `computer_vision` directory and run:

```bash
cd computer_vision
python test.py
```

### 3. Testing Process

The test script will test two models sequentially:

1. **Standard YOLO Model Test** (using YOLO11l pretrained model)
   - Uses COCO dataset pretrained classes
   - Results saved in `Result_Occupancy/` and `Result_Seats/` folders

2. **Custom Trained Model Test** (using self-trained models)
   - Uses models from `Models/` directory
   - Press Enter to continue to this test

### 4. View Results

After testing, detection results are saved in:
- `Result_Occupancy/`: Seat occupancy detection visualizations
- `Result_Seats/`: Total seat count detection visualizations

### 5. Configuration Parameters

You can adjust the following parameters in `test.py`:

```python
PROXIMITY_THRESHOLD = 150.0      # Person-item association distance (pixels)
ITEM_CLUSTER_THRESHOLD = 70.0    # Item clustering distance threshold (pixels)
SEAT_EXPANSION_FACTOR = 3        # Seat detection area expansion factor
IMAGE_SIZE = 640                 # Input image size
CONFIDENCE_THRESHOLD = 0.4       # Detection confidence threshold
DEVICE = 'auto'                  # Device selection ('auto', 'cpu', 'cuda', '0')
DEBUG_MODE = False               # Enable debug mode
```

---

## Training Models

**Important Note**: Due to the large size of training datasets, they cannot be uploaded to GitHub. The following instructions assume you have prepared the training datasets.

### 1. Train Person and Item Detection Model

#### Prepare Dataset

Organize the dataset in YOLO format:

```
PersonAndItems/
├── data.yaml          # Dataset configuration file
├── train/
│   ├── images/        # Training images
│   └── labels/        # Annotation files (.txt)
└── val/
    ├── images/        # Validation images
    └── labels/        # Annotation files (.txt)
```

#### Example `data.yaml`

```yaml
path: ./PersonAndItems
train: train/images
val: val/images

nc: 31  # Number of classes (30 item classes + 1 person class)
names: ['item_class_0', 'item_class_1', ..., 'person']
```

#### Run Training Script

```bash
cd computer_vision
python train_person_and_item.py
```

#### Training Parameters

- **Epochs**: 150
- **Image Size**: 640
- **Batch Size**: 4
- **Freeze Layers**: First 15 layers
- **Patience**: 30 (early stopping)
- **Optimizer**: AdamW
- **Learning Rate**: 0.0005 → 0.00005 (cosine decay)
- **Data Augmentation**: Mosaic, Mixup, Copy-Paste

After training, the best model is saved at:
```
runs/person_and_items/person_and_items_run/weights/best.pt
```

### 2. Train Seat Detection Model

#### Prepare Dataset

Dataset structure similar to above:

```
Seat/
├── data.yaml
├── train/
│   ├── images/
│   └── labels/
└── val/
    ├── images/
    └── labels/
```

#### Example `data.yaml`

```yaml
path: ./Seat
train: train/images
val: val/images

nc: 2  # Seat classes (chair and sofa)
names: ['chair', 'sofa']
```

#### Run Training Script

```bash
cd computer_vision
python train_seat_model.py
```

#### Training Parameters

- **Epochs**: 100
- **Image Size**: 640
- **Batch Size**: 8
- **Base Model**: YOLO11x

After training, the model is saved at:
```
runs/detect/HKU_SeatCounter_v1/weights/best.pt
```

### 3. Using Trained Models

Copy trained models to their respective locations:

```bash
# Person and item detection model
cp runs/person_and_items/person_and_items_run/weights/best.pt Models/person_and_item/best.pt

# Seat detection model
cp runs/detect/HKU_SeatCounter_v1/weights/best.pt Models/chair_and_sofa/best.pt
```

Then run `test.py` for testing.

---

## Technical Details

### Detection Logic

1. **Dual Model Detection**:
   - Occupancy Model detects people and items
   - Seat Model detects seat positions

2. **Spatial Filtering**:
   - Only items on or near seats are counted as hogging
   - Uses seat expansion factor to cover desk areas

3. **Association Filtering**:
   - Items within threshold distance of people are not separately counted
   - Avoids double counting same seat occupancy

4. **Clustering Analysis**:
   - Nearby items are clustered into one hogging region
   - Reduces false positives and duplicate detections

### Performance Optimization

- Automatic GPU/CPU device selection
- Mixed precision training support (AMP)
- Adjustable image size for speed-accuracy tradeoff
- Checkpoint resumption support

---

## FAQ

### Q1: What if CUDA is not available?

If your system doesn't support CUDA, it will automatically use CPU. You can also manually specify:

```python
detector = SeatOccupancyDetector(
    occupancy_model_path=...,
    seat_model_path=...,
    device='cpu'  # Force CPU usage
)
```

### Q2: How to adjust detection accuracy?

Adjust the `CONFIDENCE_THRESHOLD` parameter in `test.py`:
- Increase threshold (e.g., 0.6): Reduces false positives, may miss detections
- Decrease threshold (e.g., 0.3): Improves recall, may increase false positives

### Q3: Out of memory during training?

Reduce the `batch` parameter:

```python
results = model.train(
    batch=2,  # Reduce from 4/8 to 2
    ...
)
```

Or use a smaller model (e.g., `yolo11m.pt` or `yolo11s.pt`).

---

## System Requirements

- **Python**: 3.8+
- **CUDA**: 11.0+ (optional, for GPU acceleration)
- **VRAM**: At least 6GB (for training)
- **RAM**: At least 8GB

---

## License

This project follows the respective open-source licenses. YOLO models use AGPL-3.0 license.