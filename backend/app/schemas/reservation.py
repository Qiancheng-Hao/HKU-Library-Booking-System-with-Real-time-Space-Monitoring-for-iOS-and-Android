import enum
import uuid
from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models import ReservationStatus
from .facility import FacilitySummary
from .user import UserBase


class ReservationCreate(BaseModel):
    facility_id: int = Field(..., ge=1)
    reservation_date: date
    start_time: time
    end_time: time
    user_full_name: str = Field(..., min_length=2, max_length=255)
    user_email: EmailStr
    notes: str | None = None

    @field_validator("end_time")
    @classmethod
    def validate_time_order(cls, value: time, info) -> time:
        start_time = info.data.get("start_time")
        if start_time and value <= start_time:
            raise ValueError("end_time must be later than start_time")
        return value


class ReservationPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    reservation_date: date
    start_time: time
    end_time: time
    status: ReservationStatus
    notes: str | None = None
    created_at: datetime
    cancelled_at: datetime | None = None
    facility: FacilitySummary
    user: UserBase

class ReservationListResponse(BaseModel):
    items: list[ReservationPublic]
    total: int


class TimeSlotStatus(str, enum.Enum):
    available = "available"
    reserved = "reserved"
    unavailable = "unavailable"


class TimeSlot(BaseModel):
    start_time: time
    end_time: time
    status: TimeSlotStatus
    reservation_id: uuid.UUID | None = None
    user_name: str | None = None


class FacilityTimeslotResponse(BaseModel):
    facility_id: int
    facility_name: str
    date: date
    slot_interval_minutes: int
    slots: list[TimeSlot]

