import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import Reservation, ReservationStatus
from app.schemas.reservation import ReservationCreate, ReservationPublic
from app.services.reservation_service import ReservationService

router = APIRouter(prefix="/reservations", tags=["Reservations"])


@router.post("", response_model=ReservationPublic, status_code=status.HTTP_201_CREATED)
def create_reservation(
    payload: ReservationCreate,
    db: Session = Depends(get_db),
) -> ReservationPublic:
    service = ReservationService(db)
    facility = service.get_facility(payload.facility_id)
    service.enforce_lead_time(payload.reservation_date)
    service.ensure_slot_within_facility_hours(
        facility, payload.start_time, payload.end_time
    )
    service.ensure_slot_available(
        facility_id=facility.id,
        reservation_date=payload.reservation_date,
        start_time=payload.start_time,
        end_time=payload.end_time,
    )
    user = service.get_or_create_user(
        full_name=payload.user_full_name,
        email=payload.user_email,
    )

    reservation = Reservation(
        user_id=user.id,
        facility_id=facility.id,
        reservation_date=payload.reservation_date,
        start_time=payload.start_time,
        end_time=payload.end_time,
        status=ReservationStatus.confirmed,
        notes=payload.notes,
    )

    db.add(reservation)
    db.commit()
    db.refresh(reservation)
    return reservation


@router.delete("/{reservation_id}", response_model=ReservationPublic)
def cancel_reservation(
    reservation_id: uuid.UUID,
    db: Session = Depends(get_db),
) -> ReservationPublic:
    reservation = db.get(Reservation, reservation_id)
    if not reservation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reservation not found.",
        )

    service = ReservationService(db)
    service.cancel_reservation(reservation)
    db.commit()
    db.refresh(reservation)
    return reservation

