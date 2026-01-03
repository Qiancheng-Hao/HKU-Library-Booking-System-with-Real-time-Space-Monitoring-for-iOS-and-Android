from fastapi import APIRouter, File, Query, UploadFile

from app.schemas.occupancy_cv import OccupancyEstimateResponse
from app.services.occupancy_cv_service import estimate_occupancy_from_image_bytes


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

