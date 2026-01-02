import os

# Set environment variables BEFORE importing torch/ultralytics
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["OMP_NUM_THREADS"] = "1"

import torch
from ultralytics import YOLO
from pathlib import Path

# ==============================
# Settings
# ==============================
current_path = os.path.abspath(__file__)
DATASET_ROOT = os.path.join(os.path.dirname(current_path), "fyp", "person_and_item", "dataset", "person_and_item_dataset")
DATA_YAML = os.path.join(DATASET_ROOT, "data.yaml")
PROJECT_DIR = os.path.join(os.path.dirname(current_path), "fyp", "person_and_item")
CHECKPOINT_NAME = "result"

# ==============================
#v Checkpoint Detection
# ==============================
def get_checkpoint(project_dir, name, mode='resume_last'):
    checkpoint_path = Path(project_dir) / name / "weights"/"last.pt"
    if checkpoint_path.exists():
        print(f"\n Found checkpoint: {checkpoint_path}")
        return str(checkpoint_path)
    return None
# ==============================
# Main Training Process
# ==============================
if __name__ == '__main__':
    resume_path = get_checkpoint(PROJECT_DIR, CHECKPOINT_NAME)
    
    if resume_path:
        print(f" Resuming training from checkpoint: {resume_path}")
        model = YOLO(resume_path)
        result = model.train(resume=True)
    else:
        print(" Starting new training...")
        model = YOLO("yolo11l.pt")
            
            # Core Optimization
        result = model.train(
            freeze=15,
            patience=30,             # Increased from 10 to allow more exploration
            device=0,
            workers=4,
                
            # Project Management
            project=PROJECT_DIR,
            name=CHECKPOINT_NAME,
            exist_ok=True,
                
                # Training Strategy (Optimized)
            pretrained=True,
            optimizer="AdamW",
            lr0=0.0005,              # Reduced from 0.001 for fine-tuning
            lrf=0.001,               # Reduced from 0.01 for smoother decay
            weight_decay=0.0005,
                
                # Data Augmentation (Optimized for person/item detection)
            cache=False,            
            augment=True,
            degrees=10.0,            # Reduced for more stable detection
            translate=0.15,          # Increased for better position variance
            scale=0.8,               # Reduced for more scale variance
            shear=1.0,               # Reduced to avoid unrealistic distortions
            perspective=0.0001,      # Small value for subtle perspective changes
            flipud=0.0,              # Keep 0 for person detection
            fliplr=0.5,              # Good for horizontal symmetry
            mosaic=1.0,              # Keep strong mosaic
            mixup=0.1,               # Slightly reduced
            copy_paste=0.05,         # Reduced to avoid artifacts
            close_mosaic=15,         # Earlier mosaic closure for stability
                
                # Advanced Techniques
            amp=True,
            rect=False,
            cos_lr=True,
            dropout=0.1,
                
                # Save Strategy
            save=True,
            save_period=10,
                
                # Monitoring
            plots=True,
            verbose=True,
            val=True
        )
    
    print("\n" + "="*60)
    print(" Training Completed")
    print(f" Model Directory: {PROJECT_DIR}/{CHECKPOINT_NAME}/weights/")
    print("="*60)