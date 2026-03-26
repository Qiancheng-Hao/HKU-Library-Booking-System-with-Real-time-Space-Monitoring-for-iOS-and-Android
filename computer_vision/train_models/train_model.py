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
HOME_DIR = os.getenv("HOME")
PROJECT_DIR = os.path.join(HOME_DIR, "fyp", "all")
DATASET_ROOT = os.path.join(PROJECT_DIR, "dataset", "COCO_Filtered_YOLO")
DATA_YAML = os.path.join(DATASET_ROOT, "data.yaml")
CHECKPOINT_NAME = "result"


# ==============================
# Checkpoint Detection
# ==============================
def get_checkpoint(project_dir, name):
    checkpoint_path = Path(project_dir) / name / "weights" / "last.pt"
    if checkpoint_path.exists():
        print(f"\n Found checkpoint: {checkpoint_path}")
        return str(checkpoint_path)
    return None


# ==============================
# Main Training Process
# ==============================
if __name__ == "__main__":
    print(f"CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"GPU: {torch.cuda.get_device_name(0)}")

    resume_path = get_checkpoint(PROJECT_DIR, CHECKPOINT_NAME)

    if resume_path:
        print(f" Resuming training from checkpoint: {resume_path}")
        model = YOLO(resume_path)
        results = model.train(resume=True)
    else:
        print(" Starting new training...")
        model = YOLO("yolo11x.pt")

        print("--- Starting unified model training (11 classes) ---")
        results = model.train(
            data=DATA_YAML,
            epochs=150,
            imgsz=640,

            # Core Optimization
            freeze=15,
            patience=30,
            device=0,
            batch=8,
            workers=4,

            # Project Management
            project=PROJECT_DIR,
            name=CHECKPOINT_NAME,
            exist_ok=True,

            # Training Strategy
            pretrained=True,
            optimizer="AdamW",
            lr0=0.0005,
            lrf=0.001,
            weight_decay=0.0005,

            # Data Augmentation
            cache=False,
            augment=True,
            degrees=10.0,
            translate=0.15,
            scale=0.8,
            shear=1.0,
            perspective=0.0001,
            flipud=0.0,
            fliplr=0.5,
            mosaic=1.0,
            mixup=0.1,
            copy_paste=0.05,
            close_mosaic=15,

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
            val=True,
        )

    print("\n" + "=" * 60)
    print(" Training Completed")
    print(f" Model Directory: {PROJECT_DIR}/{CHECKPOINT_NAME}/weights/")
    print("=" * 60)
