## 📁 Project Structure

```
HKU-Library-Booking-System/
└── computer_vision/                 # Seat occupancy detection
    ├── core/
    │   ├── seat_occupancy_detector.py  # Main detector class
    │   └── preprocess_image.ipynb      # Image preprocessing tools
    ├── models/
    │   ├── chair_and_sofa/
    │   │   └── best.pt                 # Seat detection model
    │   └── person_and_item/
    │       ├── v1/best.pt              # Person & item detection v1
    │       └── v2/best.pt              # Person & item detection v2
    ├── test/
    │   ├── test.py                     # Testing script
    │   └── data/                       # Test images
    └── train_models/
        ├── auto_label.ipynb            # Automatic annotation tool for custom datasets
        ├── train_person_and_item.py    # Training script for person/item model
        ├── train_seat_model.py         # Training script for seat model
        └── fix_dataset_labels.py       # Dataset preprocessing utilities
```


🚀 Installation

### Prerequisites

- Python 3.8 or higher
- Anaconda or Miniconda (recommended)
- CUDA 11.0+ (optional, for GPU acceleration)

### Step 1: Clone the Repository

```bash
git clone https://github.com/Qiancheng-Hao/HKU-Library-Booking-System-with-Real-time-Space-Monitoring-for-iOS-and-Android.git
cd HKU-Library-Booking-System-with-Real-time-Space-Monitoring-for-iOS-and-Android
```

### Step 2: Install Dependencies

#### Option A: Using Conda (Recommended)

```bash
# Create a new conda environment
conda create -n hku-library python=3.8
conda activate hku-library

# Install OpenCV
conda install -c conda-forge opencv

# Install PyTorch with CUDA 12.6 support
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu126

# Install other dependencies
pip install ultralytics selenium webdriver-manager fastmcp openai agent-framework
```

#### Option B: Using pip only

```bash
# Install all dependencies
pip install opencv-python torch torchvision ultralytics selenium webdriver-manager fastmcp openai agent-framework
```

**Note**: If your system doesn't support CUDA, install the CPU version of PyTorch:

```bash
pip3 install torch torchvision
```

### Step 3: Verify Installation

```python
python -c "import cv2, torch, ultralytics; print('All dependencies installed successfully!')"
```

---

## 👁️ Computer Vision Module

### Core Features

#### 1. Dual-Model Architecture

- **Occupancy Model**: Detects people and items (backpacks, laptops, books, etc.)
- **Seat Model**: Detects seat positions (chairs and sofas)

#### 2. Intelligent Occupancy Logic

- ✅ Detected people are directly counted as occupied
- 🎒 Items are clustered and checked if they are on seats
- 🔍 Items associated with people are filtered (no double counting)
- ❌ Items off seats are ignored

#### 3. Color-Coded Visualization


| Color     | Meaning                          | Counted as Occupied?           |
| --------- | -------------------------------- | ------------------------------ |
| 🟢 Green  | People                           | ✅ Yes                         |
| 🔴 Red    | Hogging items (no person nearby) | ✅ Yes                         |
| 🔵 Blue   | Items with people                | ❌ No (person already counted) |
| 🟡 Yellow | Items off seats                  | ❌ No                          |
| 🔵 Cyan   | Seat positions                   | N/A (reference)                |

### Quick Start

#### 1. Prepare Test Images

Place test images in the `computer_vision/test/data/` folder. Supported formats:

- `.jpg`
- `.jpeg`
- `.png`
- `.bmp`

#### 2. Run Test Script

Navigate to the `computer_vision` directory and run:

```bash
cd computer_vision/test
python test.py
```

#### 3. Testing Process

The test script will test two models sequentially:

1. **Standard YOLO Model Test** (using YOLO11l pretrained model)

   - Uses COCO dataset pretrained classes
   - Results saved in `standard_model_results/` and `standard_model_seats_results/` folders
2. **Custom Trained Model Test** (using self-trained models)

   - Uses models from `computer_vision/models/` directory
   - Results saved in `self-trained_model_results/` and `self-trained_model_seats_results/` folders
   - Press Enter to continue to this test

#### 4. View Results

After testing, detection results are saved with annotated images showing:

- Detected occupancy (people and hogging items)
- Total seat counts
- Color-coded bounding boxes

#### 5. Configuration Parameters

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
