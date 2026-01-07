from pydantic import BaseModel


class OccupancyEstimateResponse(BaseModel):
    time_stamp: str
    location: str
    area: str
    total_number_of_person: int
    total_number_of_hogging_items: int
    total_number_of_seats: int
    occupancy_rate: float


class OccupancyVideoFrameResult(OccupancyEstimateResponse):
    frame_index: int
    video_time_s: float


class OccupancyVideoEstimateSummary(BaseModel):
    frames: int
    valid_frames: int
    avg_occupancy_rate: float
    max_occupancy_rate: float


class OccupancyVideoEstimateResponse(BaseModel):
    location: str
    area: str
    interval_seconds: float
    results: list[OccupancyVideoFrameResult]
    summary: OccupancyVideoEstimateSummary


class LibraryOccupancyItem(BaseModel):
    libraryId: str
    libraryName: str
    occupancyRate: float
    distanceFromUser: float
    isOpen: bool
    openingHours: str | None = None
    lastUpdated: str | None = None


class RealtimeOccupancyResponse(BaseModel):
    libraries: list[LibraryOccupancyItem]
