from __future__ import annotations

import os
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from pathlib import Path

import numpy as np
from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import SessionLocal
from app.models.occupancy import AreaOccupancySnapshot, CameraSource, OccupancyLog


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
    # if settings.cv_occupancy_model_path and settings.cv_seat_model_path:
    #     return settings.cv_occupancy_model_path, settings.cv_seat_model_path

    root = _repo_root()
    occupancy_model = _pick_existing_path(
        root / "computer_vision" / "Models" / "person_and_item" / "v2" / "best.pt",
        root / "computer_vision" / "models" / "person_and_item" / "v2" / "best.pt",
    )
    seat_model = _pick_existing_path(
        root / "computer_vision" / "yolo11l.pt"
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


# def estimate_occupancy_from_image_bytes(
#     *,
#     image_bytes: bytes,
#     location: str = "",
#     area: str = "",
# ) -> dict:
#     image = decode_image_bytes(image_bytes)
#     detector = get_detector()

#     result = detector.get_occupancy_stats_with_seats(
#         image,
#         confidence_threshold=settings.cv_confidence_threshold,
#         proximity_threshold=settings.cv_proximity_threshold,
#         item_cluster_threshold=settings.cv_item_cluster_threshold,
#         seat_expansion_factor=settings.cv_seat_expansion_factor,
#         use_preprocessing=False,
#         visualize=False,
#         imgsz=settings.cv_imgsz,
#         seat_imgsz=settings.cv_seat_imgsz,
#         location=location,
#         area=area,
#         hogging_item_class_id=list(range(23)),
#         person_class_id=23,
#         seat_class_id=[56,57]
#     )
#     return result


def estimate_occupancy_from_frame(
    *,
    frame: np.ndarray,
    location: str = "",
    area: str = "",
) -> dict:
    detector = get_detector()
    result = detector.get_occupancy_stats_with_seats(
        frame,
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
        hogging_item_class_id=list(range(23)),
        person_class_id=23,
        seat_class_id=[56,57]
    )
    return result


def save_occupancy_log(
    db: Session,
    *,
    location: str,
    area: str,
    stats: dict,
    source: str | None = None,
    frame_index: int | None = None,
) -> None:
    log_entry = OccupancyLog(
        location=location,
        area=area,
        total_people=int(stats.get("total_number_of_person", 0) or 0),
        total_hogging=int(stats.get("total_number_of_hogging_items", 0) or 0),
        total_seats=int(stats.get("total_number_of_seats", 0) or 0),
        occupancy_rate=float(stats.get("occupancy_rate", -1.0) or -1.0),
        video_source=source,
        frame_index=frame_index,
    )
    db.add(log_entry)


def aggregate_area_occupancy_from_logs(
    db: Session,
    *,
    window_seconds: int,
    now: datetime | None = None,
) -> list[dict]:
    if window_seconds <= 0:
        raise ValueError("window_seconds must be > 0")

    now = now or datetime.now(timezone.utc)
    cutoff = now - timedelta(seconds=window_seconds)

    source_expr = func.coalesce(OccupancyLog.video_source, "")
    stmt = (
        select(
            OccupancyLog.location,
            OccupancyLog.area,
            source_expr.label("source"),
            func.avg(OccupancyLog.occupancy_rate).label("avg_rate"),
            func.count(OccupancyLog.id).label("sample_count"),
        )
        .where(
            OccupancyLog.captured_at >= cutoff,
            OccupancyLog.location.is_not(None),
            OccupancyLog.area.is_not(None),
            OccupancyLog.occupancy_rate >= 0,
        )
        .group_by(OccupancyLog.location, OccupancyLog.area, source_expr)
        .order_by(OccupancyLog.location.asc(), OccupancyLog.area.asc())
    )

    rows = db.execute(stmt).all()
    by_area: dict[tuple[str, str], list[tuple[float, int]]] = {}
    for row in rows:
        location = str(row.location)
        area = str(row.area)
        avg_rate = float(row.avg_rate) if row.avg_rate is not None else -1.0
        sample_count = int(row.sample_count or 0)
        if avg_rate < 0:
            continue
        by_area.setdefault((location, area), []).append((avg_rate, sample_count))

    aggregates: list[dict] = []
    for (location, area), camera_rates in by_area.items():
        if not camera_rates:
            continue
        combined_rate = sum(r for r, _ in camera_rates) / len(camera_rates)
        total_samples = sum(c for _, c in camera_rates)
        aggregates.append(
            {
                "location": location,
                "area": area,
                "occupancy_rate": float(combined_rate),
                "sample_count": int(total_samples),
            }
        )

    aggregates.sort(key=lambda x: (x["location"], x["area"]))
    return aggregates


def compute_and_store_area_snapshots(*, window_seconds: int) -> int:
    now = datetime.now(timezone.utc)
    with SessionLocal() as db:
        aggregates = aggregate_area_occupancy_from_logs(db, window_seconds=window_seconds, now=now)
        for item in aggregates:
            db.add(
                AreaOccupancySnapshot(
                    location=item["location"],
                    area=item["area"],
                    occupancy_rate=item["occupancy_rate"],
                    sample_count=item["sample_count"],
                    window_seconds=window_seconds,
                    measured_at=now,
                )
            )
        db.commit()
        return len(aggregates)


def run_camera_capture_cycle() -> int:
    import cv2

    now = datetime.now(timezone.utc)
    captured = 0
    with SessionLocal() as db:
        cameras = (
            db.execute(select(CameraSource).where(CameraSource.enabled.is_(True)))
            .scalars()
            .all()
        )
        for camera in cameras:
            cap = cv2.VideoCapture(camera.stream_url)
            try:
                ok, frame = cap.read()
            finally:
                cap.release()
            if not ok or frame is None:
                continue

            stats = estimate_occupancy_from_frame(
                frame=frame,
                location=camera.location,
                area=camera.area,
            )
            save_occupancy_log(
                db,
                location=camera.location,
                area=camera.area,
                stats=stats,
                source=camera.name,
                frame_index=None,
            )
            camera.last_captured_at = now
            db.add(camera)
            db.commit()
            captured += 1
    return captured


# def estimate_occupancy_from_video_bytes(
#     *,
#     video_bytes: bytes,
#     video_filename: str = "video",
#     interval_seconds: float = 2.0,
#     max_frames: int | None = None,
#     location: str = "",
#     area: str = "",
# ) -> dict:
#     import cv2

#     if not np.isfinite(interval_seconds):
#         raise HTTPException(
#             status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
#             detail="interval_seconds must be a finite number.",
#         )
#     if interval_seconds <= 0:
#         raise HTTPException(
#             status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
#             detail="interval_seconds must be > 0.",
#         )
#     if max_frames is not None and max_frames <= 0:
#         raise HTTPException(
#             status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
#             detail="max_frames must be > 0 when provided.",
#         )

#     suffix = Path(video_filename).suffix or ".mp4"
#     tmp_path: str | None = None
#     cap = None

#     try:
#         with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
#             tmp.write(video_bytes)
#             tmp_path = tmp.name

#         cap = cv2.VideoCapture(tmp_path)
#         if not cap.isOpened():
#             raise HTTPException(
#                 status_code=status.HTTP_400_BAD_REQUEST,
#                 detail="Invalid or unsupported video file.",
#             )

#         fps = float(cap.get(cv2.CAP_PROP_FPS) or 0.0)
#         if fps <= 0:
#             fps = 25.0

#         frame_step = max(1, int(round(fps * interval_seconds)))
#         detector = get_detector()

#         results: list[dict] = []
#         frame_index = 0
#         sampled = 0
#         while True:
#             cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
#             ok, frame = cap.read()
#             if not ok:
#                 break

#             stats = detector.get_occupancy_stats_with_seats(
#                 frame,
#                 confidence_threshold=settings.cv_confidence_threshold,
#                 proximity_threshold=settings.cv_proximity_threshold,
#                 item_cluster_threshold=settings.cv_item_cluster_threshold,
#                 seat_expansion_factor=settings.cv_seat_expansion_factor,
#                 use_preprocessing=False,
#                 visualize=False,
#                 imgsz=settings.cv_imgsz,
#                 seat_imgsz=settings.cv_seat_imgsz,
#                 location=location,
#                 area=area,
#                 hogging_item_class_id=list(range(23)),
#                 person_class_id=23,
#                 seat_class_id=[56,57]
#             )

#             results.append(
#                 {
#                     "frame_index": frame_index,
#                     "video_time_s": frame_index / fps,
#                     **stats,
#                 }
#             )

#             try:
#                 with SessionLocal() as db:
#                     save_occupancy_log(
#                         db,
#                         location=location,
#                         area=area,
#                         stats=stats,
#                         source=Path(video_filename).name,
#                         frame_index=frame_index,
#                     )
#                     db.commit()
#             except Exception:
#                 print(f"Failed to save log for frame {frame_index}")

#             sampled += 1
#             if max_frames is not None and sampled >= max_frames:
#                 break
#             frame_index += frame_step

#         if not results:
#             raise HTTPException(
#                 status_code=status.HTTP_400_BAD_REQUEST,
#                 detail="No frames could be decoded from the video.",
#             )

#         valid_rates = [r["occupancy_rate"] for r in results if r.get("occupancy_rate", -1) >= 0]
#         summary = {
#             "frames": len(results),
#             "valid_frames": len(valid_rates),
#             "avg_occupancy_rate": float(sum(valid_rates) / len(valid_rates)) if valid_rates else -1.0,
#             "max_occupancy_rate": float(max(valid_rates)) if valid_rates else -1.0,
#         }

#         return {
#             "location": location,
#             "area": area,
#             "interval_seconds": interval_seconds,
#             "results": results,
#             "summary": summary,
#         }
#     finally:
#         if cap is not None:
#             cap.release()
#         if tmp_path is not None:
#             try:
#                 os.remove(tmp_path)
#             except OSError:
#                 pass
