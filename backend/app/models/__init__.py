"""SQLAlchemy models for the HKU Library Booking backend."""

from .ai_session import AISession
from .facility import Facility
from .facility_type import FacilityType
from .library import Library
from .library_alias import LibraryAlias
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
    "AISession",
    "AreaOccupancySnapshot",
    "CameraSource",
    "Facility",
    "FacilityType",
    "Library",
    "LibraryAlias",
    # "LibraryOccupancySnapshot",
    # "LibraryOccupancyStatistic",
    "OccupancyLog",
    "OccupancyPeriod",
    "Reservation",
    "ReservationStatus",
    "User",
]
