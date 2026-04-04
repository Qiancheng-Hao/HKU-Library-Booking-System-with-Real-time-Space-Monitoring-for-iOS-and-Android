from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

import uuid

from app.core.config import settings
from app.models import Facility, Reservation, ReservationStatus, User


class ReservationService:
    """Domain logic for creating and cancelling reservations."""

    def __init__(self, db: Session):
        self.db = db

    def get_facility(self, facility_id: int) -> Facility:
        facility = self.db.get(Facility, facility_id)
        if not facility:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Facility not found.",
            )
        if not facility.is_active:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Facility is inactive.",
            )
        if not facility.is_bookable:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Facility is not currently bookable.",
            )
        return facility

    def ensure_slot_within_facility_hours(
        self, facility: Facility, reservation_date: date, start_time: time, end_time: time
    ) -> None:
        if start_time >= end_time:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="End time must be later than start time.",
            )

        if start_time < facility.open_time or end_time > facility.close_time:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Requested time is outside facility operating hours.",
            )

        duration = datetime.combine(date.min, end_time) - datetime.combine(date.min, start_time)
        slot_minutes = int(duration.total_seconds() // 60)
        if slot_minutes % facility.slot_interval_minutes != 0:
            if end_time != facility.close_time:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Reservation duration must align with facility slot interval.",
                )

    def ensure_slot_available(
        self,
        facility_id: int,
        reservation_date: date,
        start_time: time,
        end_time: time,
    ) -> None:
        overlap_stmt = (
            select(Reservation)
            .where(
                Reservation.facility_id == facility_id,
                Reservation.reservation_date == reservation_date,
                Reservation.start_time < end_time,
                Reservation.end_time > start_time,
            )
            .limit(1)
        )
        overlap = self.db.execute(overlap_stmt).scalar_one_or_none()
        if overlap:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Time slot already reserved.",
            )

    def ensure_user_has_no_overlap(
        self,
        user_id: uuid.UUID,
        reservation_date: date,
        start_time: time,
        end_time: time,
    ) -> None:
        overlap_stmt = (
            select(Reservation)
            .where(
                Reservation.user_id == user_id,
                Reservation.reservation_date == reservation_date,
                Reservation.start_time < end_time,
                Reservation.end_time > start_time,
            )
            .limit(1)
        )
        overlap = self.db.execute(overlap_stmt).scalar_one_or_none()
        if overlap:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You already have a reservation during this time.",
            )

    def get_or_create_user(self, *, full_name: str, email: str) -> User:
        stmt = select(User).where(User.email == email)
        user = self.db.execute(stmt).scalar_one_or_none()
        if user:
            # optionally keep latest profile data
            updated = False
            if full_name and user.full_name != full_name:
                user.full_name = full_name
                updated = True
            if updated:
                self.db.add(user)
            return user

        user = User(full_name=full_name, email=email)
        self.db.add(user)
        self.db.flush()
        return user

    def enforce_lead_time(self, reservation_date: date) -> None:
        today = date.today()
        if reservation_date < today:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Reservation date cannot be in the past.",
            )

        if reservation_date > today + timedelta(days=settings.reservation_lead_days):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Reservations can be made up to {settings.reservation_lead_days} days in advance.",
            )

    def create_confirmed_reservation(
        self,
        *,
        user_id: uuid.UUID,
        facility_id: int,
        reservation_date: date,
        start_time: time,
        end_time: time,
        notes: str | None = None,
    ) -> Reservation:
        facility = self.get_facility(facility_id)
        self.enforce_lead_time(reservation_date)
        self.ensure_slot_within_facility_hours(facility, reservation_date, start_time, end_time)
        self.ensure_slot_available(
            facility_id=facility.id,
            reservation_date=reservation_date,
            start_time=start_time,
            end_time=end_time,
        )
        self.ensure_user_has_no_overlap(
            user_id=user_id,
            reservation_date=reservation_date,
            start_time=start_time,
            end_time=end_time,
        )

        reservation = Reservation(
            user_id=user_id,
            facility_id=facility.id,
            reservation_date=reservation_date,
            start_time=start_time,
            end_time=end_time,
            status=ReservationStatus.confirmed,
            notes=notes,
        )
        self.db.add(reservation)
        self.db.commit()
        self.db.refresh(reservation)
        return reservation

    def cancel_reservation(self, reservation: Reservation) -> None:
        self.db.delete(reservation)

