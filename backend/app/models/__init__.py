"""SQLAlchemy models for the HKU Library Booking backend."""

from .facility import Facility
from .library import Library
from .occupancy import (
    AreaOccupancySnapshot,
    CameraSource,
    # LibraryOccupancySnapshot,
    # LibraryOccupancyStatistic,
    OccupancyLog,
    OccupancyPeriod,
)
from .reservation import Reservation, ReservationStatus
from .user import User

__all__ = [
    "AreaOccupancySnapshot",
    "CameraSource",
    "Facility",
    "Library",
    # "LibraryOccupancySnapshot",
    # "LibraryOccupancyStatistic",
    "OccupancyLog",
    "OccupancyPeriod",
    "Reservation",
    "ReservationStatus",
    "User",
]

