from datetime import time

from pydantic import BaseModel, ConfigDict


class FacilityBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    library_id: int
    room_no: str | None = None
    facility_type_code: str | None = None
    name: str
    type: str
    capacity: int
    description: str | None = None
    open_time: time
    close_time: time
    slot_interval_minutes: int
    floor: int = 1
    x_coordinate: float = 0.0
    y_coordinate: float = 0.0
    width: float = 10.0
    height: float = 10.0
    is_active: bool = True
    is_bookable: bool = True

class FacilitySummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    library_id: int
    room_no: str | None = None
    facility_type_code: str | None = None
    name: str
    type: str
    capacity: int
    library_name: str
    x_coordinate: float = 0.0
    y_coordinate: float = 0.0
    width: float = 10.0
    height: float = 10.0
    is_active: bool = True
    is_bookable: bool = True

class FacilityDetail(FacilityBase):
    pass

