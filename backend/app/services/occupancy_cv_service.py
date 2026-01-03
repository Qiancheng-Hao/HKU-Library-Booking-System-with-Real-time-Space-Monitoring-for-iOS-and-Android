from __future__ import annotations

import os
import sys
from functools import lru_cache
from pathlib import Path

import numpy as np
from fastapi import HTTPException, status

from app.core.config import settings


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _pick_existing_path(*candidates: Path) -> Path:
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError("No candidate path exists.")

def _is_git_lfs_pointer(path: Path) -> bool:
    try:
        with path.open("rb") as f:
            head = f.read(80)
        return head.startswith(b"version https://git-lfs.github.com/spec/v1")
    except OSError:
        return False


def _resolve_model_paths() -> tuple[str, str]:
    if settings.cv_occupancy_model_path and settings.cv_seat_model_path:
        return settings.cv_occupancy_model_path, settings.cv_seat_model_path

    root = _repo_root()
    occupancy_model = _pick_existing_path(
        root / "computer_vision" / "Models" / "person_and_item" / "v2" / "best.pt",
        root / "computer_vision" / "models" / "person_and_item" / "v2" / "best.pt",
    )
    seat_model = _pick_existing_path(
        root / "computer_vision" / "Models" / "chair_and_sofa" / "best.pt",
        root / "computer_vision" / "models" / "chair_and_sofa" / "best.pt",
    )
    return str(occupancy_model), str(seat_model)


@lru_cache(maxsize=1)
def get_detector():
    os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")
    os.environ.setdefault("MKL_NUM_THREADS", "1")
    os.environ.setdefault("OMP_NUM_THREADS", "1")

    try:
        occupancy_model_path, seat_model_path = _resolve_model_paths()
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="CV model weights not found on server.",
        ) from None

    occupancy_path = Path(occupancy_model_path)
    seat_path = Path(seat_model_path)
    if _is_git_lfs_pointer(occupancy_path) or _is_git_lfs_pointer(seat_path):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="CV model weights are Git LFS pointers. Fetch real .pt files (e.g., git lfs pull) before inference.",
        )

    sys.path.insert(0, str(_repo_root()))
    from computer_vision.core.seat_occupancy_detector import SeatOccupancyDetector

    return SeatOccupancyDetector(
        occupancy_model_path=occupancy_model_path,
        seat_model_path=seat_model_path,
        debug_mode=False,
        device=settings.cv_device,
    )


def decode_image_bytes(image_bytes: bytes) -> np.ndarray:
    import cv2

    data = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if image is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image data.",
        )
    return image


def estimate_occupancy_from_image_bytes(
    *,
    image_bytes: bytes,
    location: str = "",
    area: str = "",
) -> dict:
    image = decode_image_bytes(image_bytes)
    detector = get_detector()

    result = detector.get_occupancy_stats_with_seats(
        image,
        confidence_threshold=settings.cv_confidence_threshold,
        proximity_threshold=settings.cv_proximity_threshold,
        item_cluster_threshold=settings.cv_item_cluster_threshold,
        seat_expansion_factor=settings.cv_seat_expansion_factor,
        use_preprocessing=False,
        visualize=False,
        imgsz=settings.cv_imgsz,
        seat_imgsz=settings.cv_seat_imgsz,
        location=location,
        area=area,
    )
    return result
