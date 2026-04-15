from __future__ import annotations

import os
import sys
import tempfile
import logging
import uuid
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from pathlib import Path

import numpy as np
from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as postgresql_insert
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import SessionLocal
from app.models.occupancy import AreaOccupancySnapshot, CameraSource, OccupancyLog
from app.services.occupancy_cache_service import (
    CachedAreaSnapshot,
    OccupancyStatsEvent,
    add_stats_event_to_window,
    cache_enabled,
    get_active_areas,
    get_window_events,
    store_latest_snapshot,
)

logger = logging.getLogger(__name__)


def _ensure_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _bucket_datetime(value: datetime, window_seconds: int) -> datetime:
    normalized = _ensure_utc(value)
    bucket_seconds = max(1, int(window_seconds))
    timestamp = int(normalized.timestamp())
    bucket_timestamp = timestamp - (timestamp % bucket_seconds)
    return datetime.fromtimestamp(bucket_timestamp, tz=timezone.utc)


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _pick_existing_path(*candidates: Path) -> Path:
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError("No candidate path exists.")


def _resolve_configured_model_path(
    configured_path: str | None, *fallback_candidates: Path
) -> Path:
    if configured_path:
        raw_path = Path(os.path.expandvars(os.path.expanduser(configured_path)))
        if raw_path.is_absolute():
            return _pick_existing_path(raw_path)
        return _pick_existing_path(Path.cwd() / raw_path, _repo_root() / raw_path)
    return _pick_existing_path(*fallback_candidates)


def _is_git_lfs_pointer(path: Path) -> bool:
    try:
        with path.open("rb") as f:
            head = f.read(80)
        return head.startswith(b"version https://git-lfs.github.com/spec/v1")
    except OSError:
        return False


def _resolve_model_paths() -> tuple[str, str]:
    root = _repo_root()
    occupancy_model = _resolve_configured_model_path(
        settings.cv_occupancy_model_path,
        root / "computer_vision" / "Models" / "person_and_item" / "v2" / "best.pt",
        root / "computer_vision" / "models" / "mixed" / "model_v3" / "best.pt",
    )
    seat_model = _resolve_configured_model_path(
        settings.cv_seat_model_path,
        root / "computer_vision" / "model" / "mixed" / "model_v3" / "best.pt",
        root / "computer_vision" / "yolo11l.pt",
    )
    return str(occupancy_model), str(seat_model)


def normalize_stream_url(stream_url: str) -> str:
    normalized = stream_url
    if normalized.startswith("resp:"):
        normalized = "rtsp://" + normalized[len("resp:") :]
    if normalized.startswith("rtsp:") and not normalized.startswith("rtsp://"):
        normalized = "rtsp://" + normalized[len("rtsp:") :]
    return normalized


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

    logger.info(
        "cv detector init occupancy_model=%s seat_model=%s device=%s debug=%s",
        occupancy_model_path,
        seat_model_path,
        settings.cv_device,
        settings.cv_debug_enabled,
    )
    return SeatOccupancyDetector(
        occupancy_model_path=occupancy_model_path,
        seat_model_path=seat_model_path,
        debug_mode=settings.cv_debug_enabled,
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
    logger.info(
        "cv request location=%s area=%s frame_shape=%s frame_dtype=%s conf=%.2f proximity=%.1f cluster=%.1f seat_expand=%.2f",
        location,
        area,
        getattr(frame, "shape", None),
        getattr(frame, "dtype", None),
        settings.cv_confidence_threshold,
        settings.cv_proximity_threshold,
        settings.cv_item_cluster_threshold,
        settings.cv_seat_expansion_factor,
    )
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
        hogging_item_class_id=[1,2,3,4,5,9,10],
        person_class_id=0,
        seat_class_id=[6,7,8]
    )
    logger.info("cv response location=%s area=%s stats=%s", location, area, result)
    return result


def save_occupancy_log(
    db: Session,
    *,
    location: str,
    area: str,
    stats: dict,
    source: str | None = None,
    frame_index: int | None = None,
    captured_at: datetime | None = None,
    event_id: uuid.UUID | None = None,
    camera_name: str | None = None,
) -> uuid.UUID:
    captured_value = _ensure_utc(captured_at or datetime.now(timezone.utc))
    event_uuid = event_id or uuid.uuid4()
    values = {
        "id": uuid.uuid4(),
        "captured_at": captured_value,
        "event_id": event_uuid,
        "location": location,
        "area": area,
        "total_people": int(stats.get("total_number_of_person", 0) or 0),
        "total_hogging": int(stats.get("total_number_of_hogging_items", 0) or 0),
        "total_seats": int(stats.get("total_number_of_seats", 0) or 0),
        "occupancy_rate": float(stats.get("occupancy_rate", -1.0) or -1.0),
        "video_source": source,
        "camera_name": camera_name or source,
        "frame_index": frame_index,
    }
    bind = db.get_bind()
    if bind is not None and bind.dialect.name == "postgresql":
        stmt = postgresql_insert(OccupancyLog).values(**values)
        stmt = stmt.on_conflict_do_nothing(index_elements=["captured_at", "event_id"])
        db.execute(stmt)
        return event_uuid

    db.add(OccupancyLog(**values))
    return event_uuid


def build_occupancy_stats_event(
    *,
    location: str,
    area: str,
    stats: dict,
    camera_name: str | None = None,
    captured_at: datetime | None = None,
    event_id: uuid.UUID | None = None,
) -> OccupancyStatsEvent:
    return OccupancyStatsEvent(
        event_id=event_id or uuid.uuid4(),
        location=location,
        area=area,
        captured_at=_ensure_utc(captured_at or datetime.now(timezone.utc)),
        occupancy_rate=float(stats.get("occupancy_rate", -1.0) or -1.0),
        total_people=int(stats.get("total_number_of_person", 0) or 0),
        total_hogging=int(stats.get("total_number_of_hogging_items", 0) or 0),
        total_seats=int(stats.get("total_number_of_seats", 0) or 0),
        camera_name=camera_name,
    )


def _aggregate_area_events(events: list[OccupancyStatsEvent]) -> tuple[float, int] | None:
    by_camera: dict[str, list[float]] = {}
    total_samples = 0
    for event in events:
        rate = float(event.occupancy_rate)
        if rate < 0:
            continue
        total_samples += 1
        by_camera.setdefault(event.camera_name or "", []).append(rate)

    if not by_camera:
        return None

    camera_rates = [sum(values) / len(values) for values in by_camera.values() if values]
    if not camera_rates:
        return None
    return max(0.0, sum(camera_rates) / len(camera_rates)), total_samples


def _upsert_area_snapshot(
    db: Session,
    *,
    location: str,
    area: str,
    occupancy_rate: float,
    sample_count: int,
    window_seconds: int,
    measured_at: datetime,
) -> None:
    values = {
        "id": uuid.uuid4(),
        "location": location,
        "area": area,
        "occupancy_rate": float(occupancy_rate),
        "sample_count": int(sample_count),
        "window_seconds": int(window_seconds),
        "measured_at": _ensure_utc(measured_at),
    }
    bind = db.get_bind()
    if bind is not None and bind.dialect.name == "postgresql":
        stmt = postgresql_insert(AreaOccupancySnapshot).values(**values)
        stmt = stmt.on_conflict_do_update(
            index_elements=["location", "area", "measured_at", "window_seconds"],
            set_={
                "occupancy_rate": values["occupancy_rate"],
                "sample_count": values["sample_count"],
            },
        )
        db.execute(stmt)
        return

    db.add(AreaOccupancySnapshot(**values))


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
        combined_rate = max(0, sum(r for r, _ in camera_rates) / len(camera_rates))
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
    measured_at = _bucket_datetime(now, window_seconds)
    snapshots_for_cache: list[CachedAreaSnapshot] = []

    if cache_enabled():
        active_areas = get_active_areas()
        if active_areas:
            with SessionLocal() as db:
                created_count = 0
                for location, area in active_areas:
                    events = get_window_events(
                        location=location,
                        area=area,
                        window_seconds=window_seconds,
                        measured_at=measured_at,
                    )
                    aggregate = _aggregate_area_events(events)
                    if aggregate is None:
                        continue
                    occupancy_rate, sample_count = aggregate
                    _upsert_area_snapshot(
                        db,
                        location=location,
                        area=area,
                        occupancy_rate=occupancy_rate,
                        sample_count=sample_count,
                        window_seconds=window_seconds,
                        measured_at=measured_at,
                    )
                    snapshots_for_cache.append(
                        CachedAreaSnapshot(
                            location=location,
                            area=area,
                            occupancy_rate=occupancy_rate,
                            sample_count=sample_count,
                            window_seconds=window_seconds,
                            measured_at=measured_at,
                        )
                    )
                    created_count += 1
                db.commit()

            for snapshot in snapshots_for_cache:
                store_latest_snapshot(snapshot)
            return created_count

    with SessionLocal() as db:
        aggregates = aggregate_area_occupancy_from_logs(db, window_seconds=window_seconds, now=measured_at)
        for item in aggregates:
            _upsert_area_snapshot(
                db,
                location=item["location"],
                area=item["area"],
                occupancy_rate=item["occupancy_rate"],
                sample_count=item["sample_count"],
                window_seconds=window_seconds,
                measured_at=measured_at,
            )
            snapshots_for_cache.append(
                CachedAreaSnapshot(
                    location=item["location"],
                    area=item["area"],
                    occupancy_rate=item["occupancy_rate"],
                    sample_count=item["sample_count"],
                    window_seconds=window_seconds,
                    measured_at=measured_at,
                )
            )
        db.commit()

    for snapshot in snapshots_for_cache:
        store_latest_snapshot(snapshot)
    return len(snapshots_for_cache)


def run_camera_capture_cycle() -> int:
    import cv2
    import concurrent.futures

    now = datetime.now(timezone.utc)
    captured = 0
    pending_events: list[OccupancyStatsEvent] = []
    with SessionLocal() as db:
        cameras = (
            db.execute(select(CameraSource).where(CameraSource.enabled.is_(True)))
            .scalars()
            .all()
        )
        if not cameras:
            logger.info("camera capture: no enabled cameras found")
            return 0
            
        def process_camera(camera) -> tuple[bool, dict | None]:
            stream_url = str(camera.stream_url or "")
            normalized = normalize_stream_url(stream_url)
            logger.info("camera capture: start camera=%s url=%s", camera.name, normalized)
            # Pass timeout and TCP transport to FFmpeg via environment variable
            os.environ.setdefault("OPENCV_FFMPEG_CAPTURE_OPTIONS", "rtsp_transport;tcp|timeout;5000000")
            cap = cv2.VideoCapture(normalized, cv2.CAP_FFMPEG)
            cap.set(cv2.CAP_PROP_OPEN_TIMEOUT_MSEC, 5000)
            cap.set(cv2.CAP_PROP_READ_TIMEOUT_MSEC, 5000)
            try:
                if not cap.isOpened():
                    logger.warning("camera capture: open failed camera=%s url=%s", camera.name, normalized)
                    return False, None
                ok, frame = cap.read()
            finally:
                cap.release()
                
            if not ok or frame is None:
                logger.warning("camera capture: read failed camera=%s url=%s", camera.name, normalized)
                return False, None

            try:
                stats = estimate_occupancy_from_frame(
                    frame=frame,
                    location=camera.location,
                    area=camera.area,
                )
                return True, stats
            except Exception:
                logger.exception("camera capture: inference failed camera=%s", camera.name)
                return False, None

        # Use ThreadPoolExecutor to process cameras concurrently
        with concurrent.futures.ThreadPoolExecutor(max_workers=min(10, len(cameras))) as executor:
            future_to_camera = {executor.submit(process_camera, cam): cam for cam in cameras}
            
            for future in concurrent.futures.as_completed(future_to_camera):
                camera = future_to_camera[future]
                try:
                    success, stats = future.result()
                    if success and stats:
                        event = build_occupancy_stats_event(
                            location=camera.location,
                            area=camera.area,
                            stats=stats,
                            camera_name=camera.name,
                            captured_at=now,
                        )
                        save_occupancy_log(
                            db,
                            location=camera.location,
                            area=camera.area,
                            stats=stats,
                            source=camera.name,
                            frame_index=None,
                            captured_at=now,
                            event_id=event.event_id,
                            camera_name=camera.name,
                        )
                        camera.last_captured_at = now
                        db.add(camera)
                        pending_events.append(event)
                        captured += 1
                except Exception:
                    logger.exception("camera capture: processing future failed camera=%s", camera.name)

        if captured > 0:
            db.commit()
            for event in pending_events:
                add_stats_event_to_window(event)

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
