import math
from datetime import datetime, time as time_type, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, File, Query, UploadFile
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.models import Library
from app.models.occupancy import AreaOccupancySnapshot
from app.schemas.occupancy_cv import (
    LibraryOccupancyItem,
    OccupancyEstimateResponse,
    OccupancyVideoEstimateResponse,
    RealtimeOccupancyResponse,
)
from app.services.occupancy_cv_service import (
    aggregate_area_occupancy_from_logs,
    estimate_occupancy_from_image_bytes,
    estimate_occupancy_from_video_bytes,
    save_occupancy_log,
)

def _parse_lat_lon(value: str | None) -> tuple[float, float] | None:
    if not value:
        return None
    raw = value.strip()
    if not raw:
        return None
    sep = "_" if "_" in raw else "," if "," in raw else None
    if not sep:
        return None
    parts = [p.strip() for p in raw.split(sep) if p.strip()]
    if len(parts) != 2:
        return None
    try:
        lat = float(parts[0])
        lon = float(parts[1])
    except ValueError:
        return None
    if not (-90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0):
        return None
    return lat, lon


def _haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371008.8
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = (math.sin(dphi / 2) ** 2) + math.cos(phi1) * math.cos(phi2) * (math.sin(dlambda / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return r * c


def _parse_opening_hours(value: str | None) -> tuple[time_type, time_type] | None:
    if not value:
        return None
    raw = value.strip()
    if not raw or "-" not in raw:
        return None
    start_s, end_s = [s.strip() for s in raw.split("-", 1)]
    try:
        sh, sm = [int(x) for x in start_s.split(":", 1)]
        eh, em = [int(x) for x in end_s.split(":", 1)]
    except Exception:
        return None
    try:
        start_t = time_type(hour=sh, minute=sm)
        end_t = time_type(hour=eh, minute=em)
    except ValueError:
        return None
    return start_t, end_t


def _is_open_at(*, opening_hours: str | None, at: datetime) -> bool:
    hours = _parse_opening_hours(opening_hours)
    if hours is None:
        return False
    start_t, end_t = hours
    tz = ZoneInfo(settings.default_timezone)
    at_local = at.astimezone(tz)
    now_t = at_local.timetz().replace(tzinfo=None)
    if start_t <= end_t:
        return start_t <= now_t <= end_t
    return now_t >= start_t or now_t <= end_t


router = APIRouter(prefix="/occupancy", tags=["Occupancy"])


@router.post("/estimate", response_model=OccupancyEstimateResponse)
async def estimate_occupancy(
    image: UploadFile = File(...),
    location: str = Query(default=""),
    area: str = Query(default=""),
) -> OccupancyEstimateResponse:
    image_bytes = await image.read()
    result = estimate_occupancy_from_image_bytes(
        image_bytes=image_bytes,
        location=location,
        area=area,
    )
    return OccupancyEstimateResponse(**result)


@router.post("/ingest-frame", response_model=OccupancyEstimateResponse)
async def ingest_frame(
    image: UploadFile = File(...),
    location: str = Query(default=""),
    area: str = Query(default=""),
    camera_id: str = Query(default=""),
    db: Session = Depends(get_db),
) -> OccupancyEstimateResponse:
    image_bytes = await image.read()
    result = estimate_occupancy_from_image_bytes(
        image_bytes=image_bytes,
        location=location,
        area=area,
    )
    save_occupancy_log(
        db,
        location=location,
        area=area,
        stats=result,
        source=camera_id or None,
        frame_index=None,
    )
    db.commit()
    return OccupancyEstimateResponse(**result)


@router.get("/occupancy", response_model=RealtimeOccupancyResponse)
def get_realtime_occupancy(
    latitude: float = Query(..., description="User's latitude"),
    longitude: float = Query(..., description="User's longitude"),
    radius: float = Query(default=1000, description="Search radius in meters"),
    capacityThreshold: float | None = Query(
        default=None,
        description="Only return libraries with occupancy rate below this threshold (0-100)",
    ),
    openNow: bool | None = Query(default=None, description="Whether to return only currently open libraries"),
    maxResults: int = Query(default=10, ge=1, description="Maximum number of results to return"),
    time: datetime | None = Query(default=None, description="Query occupancy rate for a specific time"),
    sortBy: str | None = Query(default=None, description="Sorting method: distance or occupancyRate"),
    db: Session = Depends(get_db),
) -> RealtimeOccupancyResponse:
    at = time or datetime.now(timezone.utc)

    libraries = db.execute(select(Library).order_by(Library.name.asc())).scalars().all()

    target_time = at
    latest_subq = (
        select(
            AreaOccupancySnapshot.location.label("location"),
            AreaOccupancySnapshot.area.label("area"),
            func.max(AreaOccupancySnapshot.measured_at).label("measured_at"),
        )
        .where(AreaOccupancySnapshot.measured_at <= target_time)
        .group_by(AreaOccupancySnapshot.location, AreaOccupancySnapshot.area)
        .subquery()
    )

    snapshot_stmt = (
        select(AreaOccupancySnapshot)
        .join(
            latest_subq,
            (AreaOccupancySnapshot.location == latest_subq.c.location)
            & (AreaOccupancySnapshot.area == latest_subq.c.area)
            & (AreaOccupancySnapshot.measured_at == latest_subq.c.measured_at),
        )
    )
    snapshots = db.execute(snapshot_stmt).scalars().all()

    by_location: dict[str, list[AreaOccupancySnapshot]] = {}
    for row in snapshots:
        if not row.location:
            continue
        by_location.setdefault(row.location, []).append(row)

    results: list[LibraryOccupancyItem] = []
    for lib in libraries:
        coords = _parse_lat_lon(lib.location)
        if coords is None:
            continue
        lib_lat, lib_lon = coords
        distance_m = _haversine_m(latitude, longitude, lib_lat, lib_lon)
        if radius is not None and radius >= 0 and distance_m > float(radius):
            continue

        is_open = _is_open_at(opening_hours=lib.opening_hours, at=at)
        if openNow is True and not is_open:
            continue

        area_rows = by_location.get(lib.name, [])
        valid = [r for r in area_rows if r.occupancy_rate is not None and float(r.occupancy_rate) >= 0]
        if valid:
            total_weight = sum(int(r.sample_count or 0) for r in valid)
            if total_weight > 0:
                rate_0_1 = sum(float(r.occupancy_rate) * int(r.sample_count or 0) for r in valid) / total_weight
            else:
                rate_0_1 = sum(float(r.occupancy_rate) for r in valid) / len(valid)
            last_updated_dt = max(
                (
                    r.measured_at.replace(tzinfo=timezone.utc)
                    if r.measured_at.tzinfo is None
                    else r.measured_at.astimezone(timezone.utc)
                )
                for r in valid
            )
            last_updated = last_updated_dt.isoformat()
        else:
            rate_0_1 = -1.0
            last_updated = None

        occupancy_percent = rate_0_1 * 100.0 if rate_0_1 >= 0 else -1.0
        if capacityThreshold is not None and occupancy_percent >= 0 and occupancy_percent >= float(capacityThreshold):
            continue
        if capacityThreshold is not None and occupancy_percent < 0:
            continue

        results.append(
            LibraryOccupancyItem(
                libraryId=str(lib.id),
                libraryName=lib.name,
                occupancyRate=float(occupancy_percent),
                distanceFromUser=float(distance_m),
                isOpen=bool(is_open),
                openingHours=lib.opening_hours,
                lastUpdated=last_updated,
            )
        )

    if sortBy == "occupancyRate":
        results.sort(key=lambda x: (x.occupancyRate < 0, x.occupancyRate))
    else:
        results.sort(key=lambda x: x.distanceFromUser)

    if maxResults is not None and maxResults >= 0:
        results = results[: int(maxResults)]

    return RealtimeOccupancyResponse(libraries=results)


@router.post("/estimate-video", response_model=OccupancyVideoEstimateResponse)
async def estimate_occupancy_video(
    video: UploadFile = File(...),
    interval_seconds: float = Query(default=2.0, ge=0.1),
    max_frames: int | None = Query(default=None, ge=1),
    location: str = Query(default=""),
    area: str = Query(default=""),
) -> OccupancyVideoEstimateResponse:
    video_bytes = await video.read()
    result = estimate_occupancy_from_video_bytes(
        video_bytes=video_bytes,
        video_filename=video.filename or "video",
        interval_seconds=interval_seconds,
        max_frames=max_frames,
        location=location,
        area=area,
    )
    return OccupancyVideoEstimateResponse(**result)
