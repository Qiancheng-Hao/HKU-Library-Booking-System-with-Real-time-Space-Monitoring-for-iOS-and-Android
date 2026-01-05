from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, Query, UploadFile
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.models.occupancy import AreaOccupancySnapshot
from app.schemas.occupancy_cv import (
    AreaOccupancyRate,
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


@router.get("/realtime", response_model=RealtimeOccupancyResponse)
def get_realtime_occupancy(
    window_seconds: int = Query(default=settings.occupancy_realtime_window_seconds, ge=1),
    use_snapshots: bool = Query(default=True),
    db: Session = Depends(get_db),
) -> RealtimeOccupancyResponse:
    refresh_seconds = settings.occupancy_realtime_refresh_seconds
    effective_window_seconds = settings.occupancy_realtime_window_seconds if use_snapshots else window_seconds

    items: list[AreaOccupancyRate] = []
    if use_snapshots:
        latest_subq = (
            select(
                AreaOccupancySnapshot.location.label("location"),
                AreaOccupancySnapshot.area.label("area"),
                func.max(AreaOccupancySnapshot.measured_at).label("measured_at"),
            )
            .group_by(AreaOccupancySnapshot.location, AreaOccupancySnapshot.area)
            .subquery()
        )

        stmt = (
            select(AreaOccupancySnapshot)
            .join(
                latest_subq,
                (AreaOccupancySnapshot.location == latest_subq.c.location)
                & (AreaOccupancySnapshot.area == latest_subq.c.area)
                & (AreaOccupancySnapshot.measured_at == latest_subq.c.measured_at),
            )
            .order_by(AreaOccupancySnapshot.location.asc(), AreaOccupancySnapshot.area.asc())
        )
        rows = db.execute(stmt).scalars().all()
        items = [
            AreaOccupancyRate(
                location=row.location,
                area=row.area,
                occupancy_rate=float(row.occupancy_rate),
                sample_count=int(row.sample_count),
                measured_at=(
                    row.measured_at.replace(tzinfo=timezone.utc)
                    if row.measured_at.tzinfo is None
                    else row.measured_at.astimezone(timezone.utc)
                ).isoformat(),
            )
            for row in rows
        ]

    if not items:
        now = datetime.now(timezone.utc)
        aggregates = aggregate_area_occupancy_from_logs(
            db,
            window_seconds=effective_window_seconds,
            now=now,
        )
        items = [
            AreaOccupancyRate(
                location=item["location"],
                area=item["area"],
                occupancy_rate=float(item["occupancy_rate"]),
                sample_count=int(item["sample_count"]),
                measured_at=now.isoformat(),
            )
            for item in aggregates
        ]

    return RealtimeOccupancyResponse(
        window_seconds=effective_window_seconds,
        refresh_seconds=refresh_seconds,
        items=items,
    )


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
