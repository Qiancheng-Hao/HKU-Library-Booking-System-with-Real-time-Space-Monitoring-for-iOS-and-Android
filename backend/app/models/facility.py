from __future__ import annotations

from datetime import time

from sqlalchemy import ForeignKey, Integer, String, Text, Time
from sqlalchemy.orm import Mapped, foreign, mapped_column, relationship

from app.core.database import Base


class Facility(Base):
    """Reservable facility (e.g., room, device) within a library."""

    __tablename__ = "facilities"
    __table_args__ = {"comment": "Reservable spaces/devices available within libraries."}

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, comment="Primary key of the facility."
    )
    library_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="FK to the parent library (Logical).",
    )
    name: Mapped[str] = mapped_column(
        String(255), nullable=False, comment="Display name for the facility."
    )
    type: Mapped[str] = mapped_column(
        String(100), default="room", nullable=False, comment="Facility category (room, seat, etc.)."
    )
    capacity: Mapped[int] = mapped_column(
        Integer, default=1, nullable=False, comment="Maximum number of occupants."
    )
    description: Mapped[str | None] = mapped_column(
        Text, nullable=True, comment="Text description outlining the facility usage."
    )
    open_time: Mapped[time] = mapped_column(
        Time, nullable=False, comment="Daily opening time for reservations."
    )
    close_time: Mapped[time] = mapped_column(
        Time, nullable=False, comment="Daily closing time for reservations."
    )
    slot_interval_minutes: Mapped[int] = mapped_column(
        Integer, default=60, nullable=False, comment="Base slot duration in minutes."
    )
    floor: Mapped[int] = mapped_column(
        Integer, default=1, nullable=False, comment="Floor number where the facility is located."
    )
    x_coordinate: Mapped[int] = mapped_column(
        Integer, default=0, nullable=False, comment="X coordinate on floor plan."
    )
    y_coordinate: Mapped[int] = mapped_column(
        Integer, default=0, nullable=False, comment="Y coordinate on floor plan."
    )
    width: Mapped[int] = mapped_column(
        Integer, default=0, nullable=False, comment="Width of the facility on floor plan."
    )
    height: Mapped[int] = mapped_column(
        Integer, default=0, nullable=False, comment="Height of the facility on floor plan."
    )

    library = relationship(
        "Library",
        back_populates="facilities",
        lazy="joined",
        primaryjoin="foreign(Facility.library_id) == Library.id",
    )
    reservations = relationship(
        "Reservation",
        back_populates="facility",
        cascade="all, delete-orphan",
        lazy="noload",
        primaryjoin="Facility.id == foreign(Reservation.facility_id)",
    )

    @property
    def library_name(self) -> str:
        return self.library.name

