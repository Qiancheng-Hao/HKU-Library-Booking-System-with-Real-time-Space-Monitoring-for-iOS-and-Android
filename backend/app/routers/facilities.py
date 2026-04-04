from datetime import date, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.models import Facility, Reservation, ReservationStatus
from app.schemas.reservation import FacilityTimeslotResponse, TimeSlot, TimeSlotStatus
from app.services.reservation_service import ReservationService

router = APIRouter(prefix="/facilities", tags=["Facilities"])


@router.get("/{facility_id}/timeslots", response_model=FacilityTimeslotResponse)
def get_facility_timeslots(
    facility_id: int,
    target_date: date = Query(default_factory=date.today, alias="date"),
    slot_minutes: int | None = Query(default=None, ge=15, le=240),
    db: Session = Depends(get_db),
) -> FacilityTimeslotResponse:
    reservation_service = ReservationService(db)
    facility = reservation_service.get_facility(facility_id)

    interval = slot_minutes or facility.slot_interval_minutes
    if interval <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Slot interval must be greater than zero.",
        )

    stmt = (
        select(Reservation)
        .options(selectinload(Reservation.user))
        .where(
            Reservation.facility_id == facility_id,
            Reservation.reservation_date == target_date,
        )
    )
    reservations = db.execute(stmt).scalars().all()

    slots: list[TimeSlot] = []
    start_dt = datetime.combine(target_date, facility.open_time)
    close_dt = datetime.combine(target_date, facility.close_time)
    
    now = datetime.now()

    while start_dt < close_dt:
        end_dt = start_dt + timedelta(minutes=interval)
        
        # edge case for last slot exceeding close time 23:00-23:45
        if end_dt > close_dt:
            end_dt = close_dt

        is_past = False
        if end_dt <= now:
            is_past = True
        
        is_cleaning_time = False
        slot_start_hour = start_dt.time().hour
        if 6 <= slot_start_hour < 8:
            is_cleaning_time = True

        overlapping = next(
            (
                r
                for r in reservations
                if r.start_time < end_dt.time() and r.end_time > start_dt.time()
            ),
            None,
        )

        status_enum = TimeSlotStatus.available
        reservation_id = None
        user_name = None

        if overlapping:
            status_enum = TimeSlotStatus.reserved
            reservation_id = overlapping.id
            user_name = overlapping.user.full_name if overlapping.user else None
        elif is_past or is_cleaning_time:
            status_enum = TimeSlotStatus.unavailable

        slots.append(
            TimeSlot(
                start_time=start_dt.time(),
                end_time=end_dt.time(),
                status=status_enum,
                reservation_id=reservation_id,
                user_name=user_name,
            )
        )

        start_dt = end_dt

    return FacilityTimeslotResponse(
        facility_id=facility.id,
        facility_name=facility.name,
        date=target_date,
        slot_interval_minutes=interval,
        slots=slots,
    )

