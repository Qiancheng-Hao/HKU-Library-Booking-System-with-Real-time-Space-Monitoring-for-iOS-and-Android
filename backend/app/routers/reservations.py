import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.models import Reservation, ReservationStatus
from app.schemas.reservation import ReservationCreate, ReservationPublic, ReservationListResponse
from app.services.reservation_service import ReservationService

router = APIRouter(prefix="/reservations", tags=["Reservations"])


@router.post("", response_model=ReservationPublic, status_code=status.HTTP_201_CREATED)
def create_reservation(
    request: Request,
    payload: ReservationCreate,
    db: Session = Depends(get_db),
) -> ReservationPublic:
    try:
        user_id = uuid.UUID(str(getattr(request.state, "user_subject")))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )

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
    service.ensure_user_has_no_overlap(
        user_id=user_id,
        reservation_date=payload.reservation_date,
        start_time=payload.start_time,
        end_time=payload.end_time,
    )

    reservation = Reservation(
        user_id=user_id,
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

    stmt = (
        select(Reservation)
        .options(
            selectinload(Reservation.facility),
            selectinload(Reservation.user),
        )
        .where(Reservation.id == reservation.id)
    )
    reservation = db.execute(stmt).scalar_one()
    return reservation


@router.delete("/{reservation_id}", status_code=status.HTTP_204_NO_CONTENT)
def cancel_reservation(
    reservation_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    reservation = db.get(Reservation, reservation_id)
    if not reservation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reservation not found.",
        )

    service = ReservationService(db)
    service.cancel_reservation(reservation)
    db.commit()
    return


@router.get("/my", response_model=ReservationListResponse)
def list_my_reservations(
    request: Request,
    db: Session = Depends(get_db),
) -> ReservationListResponse:
    try:
        user_id = uuid.UUID(str(getattr(request.state, "user_subject")))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    stmt = (
        select(Reservation)
        .options(
            selectinload(Reservation.facility),
            selectinload(Reservation.user),
        )
        .where(Reservation.user_id == user_id)
        .order_by(Reservation.reservation_date.asc(), Reservation.start_time.asc()) 
    )
    items = db.execute(stmt).scalars().all()
    return ReservationListResponse(items=items, total=len(items))

