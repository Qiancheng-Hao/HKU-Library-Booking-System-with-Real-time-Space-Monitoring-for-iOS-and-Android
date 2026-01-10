from datetime import time

from pydantic import BaseModel, ConfigDict


class FacilityBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    library_id: int
    name: str
    type: str
    capacity: int
    description: str | None = None
    open_time: time
    close_time: time
    slot_interval_minutes: int
    floor: int = 1
    x_coordinate: int = 0
    y_coordinate: int = 0
    width: int = 0
    height: int = 0

class FacilitySummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    library_id: int
    name: str
    type: str
    capacity: int
    library_name: str

class FacilityDetail(FacilityBase):
    pass

