# HKU Library Booking System with Real-time Space Monitoring

[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.0+-orange.svg)](https://pytorch.org/)
[![YOLOv11](https://img.shields.io/badge/YOLO-v11-green.svg)](https://github.com/ultralytics/ultralytics)

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Computer Vision Module](#computer-vision-module)
- [AI Booking Agent](#ai-booking-agent)
- [Training Models](#training-models)
- [Technical Details](#technical-details)
- [FAQ](#faq)
- [System Requirements](#system-requirements)
- [License](#license)

## 🎯 Overview

This project provides a comprehensive solution for HKU library management, combining:

1. **Computer Vision System**: Real-time seat occupancy detection using YOLO object detection
2. **Automated Booking Agent**: Intelligent booking system with concurrent room reservation capabilities

The system can detect library seat occupancy (both people and items hogging seats), count total seats and available seats, and distinguish between valid occupancy and hogging behavior.

## ✨ Features

### Computer Vision Module

- 🪑 **Seat Occupancy Detection**: Dual-model architecture for accurate occupancy tracking
- 👥 **Person Detection**: Identifies people occupying seats
- 🎒 **Item Detection**: Detects backpacks, laptops, books, and other items
- 🎯 **Hogging Detection**: Identifies items occupying seats without people present
- 📊 **Real-time Counting**: Tracks total seats vs. available seats
- 🎨 **Visual Feedback**: Color-coded detection results

### AI Booking Agent

- 🚀 **Concurrent Booking**: Multi-threaded booking for multiple rooms/sessions
- 🔄 **Automatic Retry**: Intelligent retry mechanism for failed bookings
- 🔐 **Secure Authentication**: Portal login with credential management
- ⚡ **High-Speed Execution**: Optimized for competitive booking scenarios
- 🎯 **Room Selection**: Flexible room and session preference handling

## 📁 Project Structure

```
HKU-Library-Booking-System/
├── README.md
├── requirements.txt
├── ai_agent/                        # Automated booking system
│   ├── booking_system.py           # Core booking logic with Selenium
│   ├── server.py                   # MCP server for booking agent
│   └── call_server.py              # Server invocation script
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
        ├── train_person_and_item.py    # Training script for person/item model
        ├── train_seat_model.py         # Training script for seat model
        └── fix_dataset_labels.py       # Dataset preprocessing utilities
```

---

## 🚀 Installation

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
pip install ultralytics selenium webdriver-manager fastmcp
```

#### Option B: Using pip only

```bash
# Install all dependencies
pip install opencv-python torch torchvision ultralytics selenium webdriver-manager fastmcp
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

---

## 🤖 AI Booking Agent

### Overview

The AI Booking Agent automates the library room booking process using Selenium WebDriver with multi-threaded concurrent booking capabilities. It can handle competitive booking scenarios where speed is critical.

### Features

- **Concurrent Multi-Room Booking**: Books multiple rooms simultaneously using thread pools
- **Pre-Login Strategy**: Logs in before booking time to minimize latency
- **Automatic Room Selection**: Attempts booking in priority order from a list of preferred rooms
- **Session Management**: Supports multiple time slot bookings in a single run
- **Headless Operation**: Runs in background without opening browser windows
- **Anti-Detection**: Configured to avoid automation detection

### Quick Start

#### 1. Configure Booking Parameters

Edit [ai_agent/server.py](ai_agent/server.py) with your booking details:

```python
username = "your_portal_uid"      # Your HKU portal ID
password = "your_password"        # Your portal password
room_type = 29                     # Room type ID
location = 5                       # Location ID
date = "20251220"                  # Booking date (YYYYMMDD)
time_slot = "14001500"            # Time slot (HHMM-HHMM)
rooms = ["258", "259", "260"]     # Preferred room numbers
```

#### 2. Run the Booking Agent

```bash
cd ai_agent
python server.py
```

#### 3. Using as MCP Server

The booking agent can be run as a Model Context Protocol (MCP) server:

```bash
python call_server.py
```

### Booking System Architecture

```python
from booking_system import OptimizedBookingSystem

# Initialize booking system
booking = OptimizedBookingSystem(
    username="u1234567",
    password="your_password",
    location=5,              # Library location
    type=29,                 # Room type
    date="20251220",         # Target date
    sessions=["14001500"]    # Time slots
)

# Initialize multiple browser instances
booking.initialize_multiple_drivers()

# Pre-login to all instances
booking.pre_login_all()

# Attempt concurrent booking
rooms = ["258", "259", "260"]
booking.concurrent_booking_attempt(rooms)
```

### Advanced Configuration

You can customize the booking behavior by modifying parameters in [ai_agent/booking_system.py](ai_agent/booking_system.py):

| Parameter          | Description                              | Default |
| ------------------ | ---------------------------------------- | ------- |
| `num_drivers`    | Number of concurrent browser instances   | 3       |
| `headless`       | Run browsers in headless mode            | True    |
| `timeout`        | Maximum wait time for elements (seconds) | 10      |
| `retry_attempts` | Number of retry attempts per booking     | 3       |

### Troubleshooting

**Chrome Driver Issues:**

- The system uses `webdriver-manager` to automatically download the correct ChromeDriver
- If issues persist, manually install ChromeDriver matching your Chrome version

**Booking Fails:**

- Check credentials are correct
- Verify the booking URL is accessible
- Ensure room IDs and time slots are valid
- Check if you've reached booking limits

**Performance Optimization:**

- Increase `num_drivers` for more concurrent attempts
- Run on a machine with better network connectivity
- Pre-login closer to the booking opening time

---

## 🎓 Training Models

> **Note**: Due to the large size of training datasets, they are not included in this repository. The following instructions assume you have prepared your own training datasets in YOLO format.

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
cd computer_vision/train_models
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
cd computer_vision/train_models
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
cp runs/person_and_items/person_and_items_run/weights/best.pt computer_vision/models/person_and_item/v2/best.pt

# Seat detection model
cp runs/detect/HKU_SeatCounter_v1/weights/best.pt computer_vision/models/chair_and_sofa/best.pt
```

Then run the test script for evaluation.

---

## 🔧 Technical Details

### Computer Vision Detection Pipeline

1. **Dual Model Detection**:

   - Occupancy Model detects people and items in the scene
   - Seat Model detects physical seat positions (chairs and sofas)
2. **Spatial Filtering**:

   - Only items on or near seats are considered for hogging detection
   - Uses seat expansion factor to cover desk/table areas adjacent to seats
   - Off-seat items are excluded from occupancy count
3. **Association Filtering**:

   - Items within threshold distance of people are not separately counted
   - Prevents double-counting the same seat (person + their belongings)
   - Uses proximity-based clustering algorithm
4. **Clustering Analysis**:

   - Nearby items are grouped into single hogging regions
   - Reduces false positives from scattered small objects
   - DBSCAN-like clustering with configurable distance threshold

### Booking System Architecture

1. **Multi-threaded Design**:

   - Thread pool executor for concurrent booking attempts
   - Separate threads for each browser instance
   - Thread-safe booking state management with locks
2. **Pre-login Optimization**:

   - Browsers login before booking time
   - Reduces latency during competitive booking window
   - Maintains session cookies for faster access
3. **Retry Mechanism**:

   - Automatic retry on transient failures
   - Exponential backoff for rate limiting
   - Stale element reference handling

### Performance Optimization

- ⚡ Automatic GPU/CPU device selection for CV models
- 🎯 Mixed precision training support (AMP) for faster training
- 📐 Adjustable image size for speed-accuracy tradeoff
- 💾 Checkpoint resumption support for interrupted training
- 🔄 Concurrent browser instances for booking speed

---

## ❓ FAQ

### Computer Vision

**Q1: What if CUDA is not available?**

The system will automatically fall back to CPU. You can also manually specify:

```python
from computer_vision.core.seat_occupancy_detector import SeatOccupancyDetector

detector = SeatOccupancyDetector(
    occupancy_model_path="models/person_and_item/v2/best.pt",
    seat_model_path="models/chair_and_sofa/best.pt",
    device='cpu'  # Force CPU usage
)
```

**Q2: How to adjust detection accuracy?**

Modify the `CONFIDENCE_THRESHOLD` parameter in the test script:

- **Increase** (e.g., 0.6): Fewer false positives, may miss some detections
- **Decrease** (e.g., 0.3): Better recall, may increase false positives

**Q3: Out of memory during training?**

Reduce the batch size:

```python
results = model.train(
    batch=2,  # Reduce from 4/8 to 2
    imgsz=640,
    # ... other parameters
)
```

Or use a smaller model variant (e.g., `yolo11m.pt` or `yolo11s.pt`).

**Q4: How accurate is the seat detection?**

Accuracy depends on:

- Image quality and lighting conditions
- Camera angle and distance
- Model training data similarity to test environment
- Typical accuracy: 85-95% for well-lit, standard library settings

### Booking System

**Q5: Why do my bookings fail?**

Common issues:

- ❌ Incorrect credentials
- ❌ Invalid room IDs or time slots
- ❌ Booking quota exceeded
- ❌ Network connectivity issues
- ❌ Booking website structure changed

**Q6: How many concurrent browsers should I use?**

Recommended settings:

- **Standard booking**: 3-5 browsers
- **High-competition**: 5-10 browsers
- **Resource-constrained**: 2-3 browsers

More browsers increase success probability but consume more system resources.

**Q7: Can I book multiple time slots?**

Yes! Pass a list of time slots to the booking system:

```python
sessions = ["14001500", "15001600", "16001700"]
booking = OptimizedBookingSystem(
    username="u1234567",
    password="password",
    location=5,
    type=29,
    date="20251220",
    sessions=sessions  # Multiple sessions
)
```

**Q8: Is this legal/allowed?**

⚠️ **Disclaimer**: This tool is for educational purposes. Always:

- Follow your institution's booking policies
- Don't abuse the system or create unfair advantages
- Use responsibly and ethically
- Respect rate limits and server resources

---

## 💻 System Requirements

### Minimum Requirements

| Component         | Requirement                                |
| ----------------- | ------------------------------------------ |
| **OS**      | Windows 10/11, macOS 10.14+, Ubuntu 18.04+ |
| **Python**  | 3.8 or higher                              |
| **RAM**     | 8GB (16GB recommended for training)        |
| **Storage** | 5GB free space                             |
| **Browser** | Chrome/Chromium (for booking agent)        |

### For GPU Acceleration

| Component          | Requirement                                 |
| ------------------ | ------------------------------------------- |
| **CUDA**     | 11.0 or higher                              |
| **GPU VRAM** | 6GB minimum (8GB+ recommended for training) |
| **GPU**      | NVIDIA GPU with compute capability 3.5+     |

### For Training Models

| Component               | Requirement                                    |
| ----------------------- | ---------------------------------------------- |
| **RAM**           | 16GB minimum                                   |
| **GPU VRAM**      | 8GB minimum (12GB+ recommended)                |
| **Storage**       | 20GB+ (for datasets and checkpoints)           |
| **Training Time** | 2-6 hours on RTX 3060 (varies by dataset size) |

---

## 📊 Performance Benchmarks

### Computer Vision Module

| Metric                          | Value                      |
| ------------------------------- | -------------------------- |
| **Inference Speed (GPU)** | ~30-50 FPS (RTX 3060)      |
| **Inference Speed (CPU)** | ~3-5 FPS (Intel i7)        |
| **Detection Accuracy**    | 85-95% (on library images) |
| **Model Size (Combined)** | ~150MB                     |

### Booking Agent

| Metric                         | Value                          |
| ------------------------------ | ------------------------------ |
| **Login Time**           | 2-4 seconds                    |
| **Booking Latency**      | <1 second (after pre-login)    |
| **Success Rate**         | 70-90% (competitive scenarios) |
| **Concurrent Instances** | Up to 10 browsers              |

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 License

This project uses components with different licenses:

- **YOLO Models**: [AGPL-3.0 License](https://github.com/ultralytics/ultralytics/blob/main/LICENSE) (Ultralytics)

Please ensure compliance with all applicable licenses when using this project.

---

## 🙏 Acknowledgments

- [Ultralytics YOLOv11](https://github.com/ultralytics/ultralytics) for the object detection framework
- [Selenium](https://www.selenium.dev/) for web automation capabilities
- [FastMCP](https://github.com/jlowin/fastmcp) for Model Context Protocol implementation
- HKU Library for the booking system infrastructure

---

## 📧 Contact

For questions, issues, or suggestions:

- **GitHub Issues**: [Create an issue](https://github.com/yourusername/HKU-Library-Booking-System/issues)
- **Email**: god@hku.hk or altiera@hku.hk

---

## ⚠️ Disclaimer

This project is developed for **educational and research purposes only**. Users are responsible for:

- Complying with HKU's IT policies and library regulations
- Using the booking system responsibly and ethically
- Not abusing or overloading university systems
- Respecting other students' fair access to resources

The developers are not responsible for any misuse of this software or violations of university policies.
