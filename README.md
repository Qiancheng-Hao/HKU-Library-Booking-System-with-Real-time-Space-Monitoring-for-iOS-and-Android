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

- 🤖 **Conversational AI Interface**: Natural language booking through GitHub Models AI
- 🌐 **Multi-User Support**: Session-based architecture for concurrent users
- 🚀 **Concurrent Booking**: Multi-threaded booking for multiple rooms/sessions
- 🗺️ **Fuzzy Location Matching**: Intelligent location and room type recognition
- 🔄 **Automatic Retry**: Intelligent retry mechanism for failed bookings
- 🔐 **Secure Authentication**: Portal login with credential management
- ⚡ **High-Speed Execution**: Optimized for competitive booking scenarios
- 🎯 **Flexible Selection**: Natural language room and session preference handling
- 📡 **RESTful API**: HTTP-based MCP server for easy frontend integration

## 📁 Project Structure

```
HKU-Library-Booking-System/
├── README.md
├── requirements.txt
├── ai_agent/                        # Automated booking system
│   ├── booking_agent.py            # AI agent with conversation interface
│   ├── booking_system.py           # Core booking logic with Selenium
│   ├── facility_mapping.py         # Location and room type mapping
│   ├── server.py                   # Multi-user MCP server with session management
│   ├── test_facility_mapping.py    # Facility mapping tests
│   ├── facility_details.txt        # Room type and location reference
│   └── API_DOCUMENTATION.md        # Complete API documentation
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

---

## 🤖 AI Booking Agent

### Overview

The AI Booking Agent is an intelligent conversational system that automates library room booking through natural language interaction. Built with GitHub Models AI and session-based architecture, it supports multiple concurrent users and handles the complete booking workflow from information gathering to execution.

### Key Features

- **Natural Language Interface**: Chat with the AI agent using everyday language
- **Multi-User Sessions**: Isolated sessions for concurrent users with automatic timeout
- **Intelligent Mapping**: Fuzzy matching for location and room type names (e.g., "Chi Wah" → "Chi Wah Learning Commons")
- **Conversation-Driven**: Agent guides users through collecting all required booking information
- **Concurrent Execution**: Multi-threaded booking for speed in competitive scenarios
- **RESTful API**: HTTP-based endpoints for easy frontend integration

### Architecture

```
Frontend/Mobile App
        ↓
  HTTP REST API (Port 8000)
        ↓
  MCP Server (server.py)
        ↓
  Session Manager
        ↓
  BookingAgent (AI Chat)
        ↓
  BookingSystem (Selenium)
        ↓
  HKU Library Website
```

### Quick Start

#### Method 1: API Server (Recommended for Production)

The AI agent runs as an HTTP server with session management for multiple users.

**Step 1: Start the server**

```bash
cd ai_agent
python server.py
```

The server starts on `http://localhost:8000` with automatic session management.

**Step 2: Create a session and chat**

```python
import requests

# Create a new booking session
response = requests.post('http://localhost:8000/tools/create_session', 
    json={
        "arguments": {
            "github_token": "your_github_token",
            "user_id": "user123"
        }
    }
)
session_id = response.json()["session_id"]

# Chat with the agent
response = requests.post('http://localhost:8000/tools/chat_with_agent',
    json={
        "arguments": {
            "session_id": session_id,
            "message": "I want to book a study room at Chi Wah tomorrow 2PM"
        }
    }
)
print(response.json()["response"])
```

**Step 3: View complete API documentation**

See [ai_agent/API_DOCUMENTATION.md](ai_agent/API_DOCUMENTATION.md) for:
- Complete API reference for all endpoints
- Request/response formats
- JavaScript/React integration examples
- Session management best practices
- Error handling guide

#### Method 2: Direct Agent Usage (Testing/Development)

For testing or standalone usage without the server:

```python
from booking_agent import BookingAgent
import asyncio

async def main():
    # Initialize agent with GitHub token
    agent = BookingAgent(github_token="your_github_token")
    
    # Start conversation
    await agent.start_conversation()
    
    # Or use programmatically
    response = await agent.chat("I want to book Chi Wah study room")
    print(response)

asyncio.run(main())
```

### Conversation Flow Example

```
Agent: Hello! I'm your HKU Library booking assistant. 
       I'll help you book a study room. What would you like to book?

User:  I want to book a study room at Chi Wah tomorrow

Agent: Great! I'll help you book a study room at Chi Wah Learning Commons.
       What time would you like to book? (e.g., 2PM, 14:00-15:00)

User:  2PM to 4PM

Agent: Perfect! Which room numbers would you prefer? 
       Available rooms: 258-266, 268-271, 274-275

User:  258, 259, 260

Agent: I have collected the following information:
       - Location: Chi Wah Learning Commons
       - Type: Study Room
       - Date: 2025-12-30
       - Time: 14:00-15:00, 15:00-16:00
       - Rooms: 258, 259, 260
       
       To proceed with booking, I need your HKU credentials.
       Please provide your UID and password.

User:  UID: u1234567, Password: ********

Agent: Executing booking... 
       Successfully booked room 258 for 14:00-15:00!
```

### Supported Locations and Room Types

The agent supports fuzzy matching for user-friendly names:

**Libraries**:
- Main Library (aliases: "main", "ml", "main lib")
- Chi Wah Learning Commons (aliases: "chi wah", "chiwah", "cw", "cwlc")
- Law Library (aliases: "law", "ll")
- Medical Library (aliases: "medical", "med")
- Music Library (aliases: "music")

**Room Types** (varies by library):
- Study Room
- Discussion Room
- Single Study Room
- Computer Room
- Studio and Editing Room
- Study Table

See [ai_agent/facility_mapping.py](ai_agent/facility_mapping.py) for complete mapping details.

### Session Management

**Features**:
- Automatic session creation with UUID
- 30-minute inactivity timeout
- Background cleanup of expired sessions
- Thread-safe concurrent access
- Per-user isolated conversation history

**API Endpoints**:
- `create_session()` - Create new user session
- `chat_with_agent()` - Send messages
- `get_session_status()` - View collected info
- `reset_session()` - Clear collected data
- `end_session()` - Explicitly end session
- `list_active_sessions()` - Admin monitoring

### Configuration

**Server Settings** (in `server.py`):
```python
SESSION_TIMEOUT_MINUTES = 30     # Auto-expire inactive sessions
CLEANUP_INTERVAL_SECONDS = 300   # Background cleanup frequency
```

**Booking Settings** (in `booking_system.py`):
```python
num_drivers = 3                  # Concurrent browser instances
headless = True                  # Run browsers in background
timeout = 10                     # Element wait timeout (seconds)
retry_attempts = 3               # Retry failed bookings
```

---

## 🎓 Training Models
### 0. Auto-Labeling Tool (NEW)

Before training, you can use the automatic labeling tool to annotate your custom dataset:

#### Purpose

The `auto_label.ipynb` notebook automates the annotation process for custom-collected images using pre-trained YOLO models. This significantly reduces manual labeling effort.

#### Usage

1. Place your unlabeled images in a folder
2. Open `computer_vision/train_models/auto_label.ipynb`
3. Configure the source folder and output paths
4. Run the notebook to generate YOLO format annotations

The tool will:
- Detect objects using existing YOLO models
- Generate `.txt` label files in YOLO format
- Allow you to review and refine annotations
- Prepare dataset for training

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

### Booking Agent

**Q5: How do I get a GitHub token for the AI agent?**

1. Go to https://github.com/settings/tokens
2. Generate a new Personal Access Token (classic)
3. Ensure it has access to GitHub Models
4. Store it securely and use in `create_session()` or agent initialization

**Q6: Session expired - what should I do?**

Sessions automatically expire after 30 minutes of inactivity. Simply create a new session:
```python
response = requests.post('http://localhost:8000/tools/create_session', ...)
```

**Q7: Why do my bookings fail?**

Common issues:

- ❌ Incorrect credentials
- ❌ Invalid room IDs or time slots
- ❌ Booking quota exceeded
- ❌ Network connectivity issues
- ❌ Booking website structure changed

**Q8: How many concurrent browsers should I use?**

Recommended settings:

- **Standard booking**: 3-5 browsers
- **High-competition**: 5-10 browsers
- **Resource-constrained**: 2-3 browsers

More browsers increase success probability but consume more system resources.

**Q9: Can the agent understand different languages?**

The agent is trained on English conversations but can handle various phrasings:
- "I want to book Chi Wah" ✅
- "Book a room at CW" ✅
- "Study room at chiwah tomorrow 2PM" ✅

**Q10: Can I book multiple time slots?**

Yes! The agent automatically handles multiple time slots:

```
User: "I want to book from 2PM to 4PM"
Agent: (Creates sessions for 14:00-15:00 AND 15:00-16:00)
```

Or pass directly to the booking system:
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
---
## 🙏 Acknowledgments

- [Ultralytics YOLOv11](https://github.com/ultralytics/ultralytics) for the object detection framework
- [Selenium](https://www.selenium.dev/) for web automation capabilities
- [FastMCP](https://github.com/jlowin/fastmcp) for Model Context Protocol implementation
- [GitHub Models](https://github.com/marketplace/models) for AI agent capabilities
- [Agent Framework](https://github.com/microsoft/agent-framework) for conversation management
- HKU Library for the booking system infrastructure
