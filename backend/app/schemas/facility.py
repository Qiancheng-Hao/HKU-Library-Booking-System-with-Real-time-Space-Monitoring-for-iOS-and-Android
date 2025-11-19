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

class FacilitySummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    type: str
    capacity: int

class FacilityDetail(FacilityBase):
    pass

