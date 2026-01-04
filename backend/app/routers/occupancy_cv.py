from fastapi import APIRouter, File, Query, UploadFile

from app.schemas.occupancy_cv import OccupancyEstimateResponse, OccupancyVideoEstimateResponse
from app.services.occupancy_cv_service import (
    estimate_occupancy_from_image_bytes,
    estimate_occupancy_from_video_bytes,
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


@router.post("/estimate-video", response_model=OccupancyVideoEstimateResponse)
async def estimate_occupancy_video(
    video: UploadFile = File(...),
    interval_seconds: float = Query(default=2.0, ge=0.1),
    max_frames: int | None = Query(default=20, ge=1),
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
