from __future__ import annotations

import enum
import uuid
from datetime import date, datetime, time

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Integer, String, Text, Time, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, foreign, mapped_column, relationship

from app.core.database import Base


class ReservationStatus(str, enum.Enum):
    """Enumeration of supported reservation statuses."""

    pending = "pending"
    confirmed = "confirmed"
    claimed = "claimed"
    unclaimed = "unclaimed"
    finished = "finished"


class Reservation(Base):
    """Represents a booking for a facility in a specific time slot."""

    __tablename__ = "reservations"
    __table_args__ = (
        {"comment": "Facility reservations with status tracking."},
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Primary key UUID for the reservation.",
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        comment="FK referencing the booking user (Logical).",
    )
    facility_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="FK referencing the reserved facility (Logical).",
    )
    reservation_date: Mapped[date] = mapped_column(
        Date, nullable=False, index=True, comment="Date of the reservation."
    )
    start_time: Mapped[time] = mapped_column(
        Time, nullable=False, comment="Slot start time."
    )
    end_time: Mapped[time] = mapped_column(Time, nullable=False, comment="Slot end time.")
    status: Mapped[ReservationStatus] = mapped_column(
        Enum(ReservationStatus, name="reservation_status"),
        default=ReservationStatus.confirmed,
        nullable=False,
        comment="Current reservation state.",
    )
    notes: Mapped[str | None] = mapped_column(
        Text, nullable=True, comment="Optional free-form requester notes."
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="Timestamp when the reservation was created.",
    )

    facility = relationship(
        "Facility",
        back_populates="reservations",
        lazy="joined",
        primaryjoin="foreign(Reservation.facility_id) == Facility.id",
    )
    user = relationship(
        "User",
        back_populates="reservations",
        lazy="joined",
        primaryjoin="foreign(Reservation.user_id) == User.id",
    )

