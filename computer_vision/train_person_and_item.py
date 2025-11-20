# -*- coding: utf-8 -*-

import os
import torch
from ultralytics import YOLO
from pathlib import Path

os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["OMP_NUM_THREADS"] = "1"

# ==============================
#v Settings
# ==============================
DATASET_ROOT = os.path.join("PersonAndItems")
DATA_YAML = os.path.join(DATASET_ROOT, "data.yaml")
PROJECT_DIR = "runs/person_and_items"
CHECKPOINT_NAME = "person_and_items_run"

# ==============================
#v Checkpoint Detection
# ==============================
def get_latest_checkpoint(project_dir, name):
    checkpoint_path = Path(project_dir) / name / "weights" / "last.pt"
    if checkpoint_path.exists():
        print(f"\n Found checkpoint: {checkpoint_path}")
        return str(checkpoint_path)
    return None

# ==============================
# Main Training Process
# ==============================
if __name__ == '__main__':
    resume_path = get_latest_checkpoint(PROJECT_DIR, CHECKPOINT_NAME)
    
    if resume_path:
        print(" Resuming training from checkpoint...")
        model = YOLO(resume_path)
        results = model.train(resume=True)
    else:
        print(" Starting new training...")
        model = YOLO("yolo11l.pt")
        
        results = model.train(
            data=DATA_YAML,
            epochs=150,
            imgsz=640,
            batch=4,
            
            # Core Optimization
            freeze=15,
            patience=30,
            device=0,
            workers=4,
            
            # Project Management
            project=PROJECT_DIR,
            name=CHECKPOINT_NAME,
            exist_ok=True,
            
            # Training Strategy
            pretrained=True,
            optimizer="AdamW",
            lr0=0.0005,
            lrf=0.01,
            weight_decay=0.0005,
            
            # Data Augmentation (Key Modifications!)
            cache=False,            
            augment=True,
            degrees=15.0,
            translate=0.1,
            scale=0.9,
            shear=2.0,
            perspective=0.0,
            flipud=0.0,
            fliplr=0.5,
            mosaic=1.0,
            mixup=0.15,
            copy_paste=0.1,
            close_mosaic=20,
            
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