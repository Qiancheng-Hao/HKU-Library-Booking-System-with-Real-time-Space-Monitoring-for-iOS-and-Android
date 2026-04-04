from pydantic import BaseModel, ConfigDict

from .facility import FacilityDetail


class LibraryBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    legacy_code: str | None = None
    name: str
    location: str | None = None
    campus: str | None = None
    description: str | None = None
    latitude: float | None = None
    longitude: float | None = None

class LibraryWithFacilities(LibraryBase):
    facilities: list[FacilityDetail]


class LibrarySummary(BaseModel):
    id: int
    legacy_code: str | None = None
    name: str
    location: str | None = None
    campus: str | None = None
    facility_count: int


class LibraryListResponse(BaseModel):
    items: list[LibrarySummary]
    total: int


class LibraryDetailResponse(BaseModel):
    library: LibraryWithFacilities

