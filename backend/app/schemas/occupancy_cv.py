from datetime import datetime

from typing import Literal

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
    area: str | None = None
    occupancyRate: float | None = None
    distanceFromUser: float
    isOpen: bool
    openingHours: str | None = None
    lastUpdated: str | None = None


class RealtimeOccupancyResponse(BaseModel):
    libraries: list[LibraryOccupancyItem]


class RealtimeOccupancyRequest(BaseModel):
    latitude: float
    longitude: float
    radius: float = 1000
    capacityThreshold: float | None = None
    openNow: bool | None = None
    maxResults: int = 10
    time: datetime | None = None
    sortBy: str | None = None


class OccupancyRecommendationRequest(BaseModel):
    latitude: float
    longitude: float
    strategy: Literal["distance", "occupancyRate"]
    userId: str | None = None
    time: datetime | None = None


class OccupancyRecommendationResponse(BaseModel):
    libraryId: str
    libraryName: str
    area: str | None = None
    occupancyRate: float | None = None
    distanceFromUser: float
    openingHours: str | None = None
    lastUpdated: str | None = None
