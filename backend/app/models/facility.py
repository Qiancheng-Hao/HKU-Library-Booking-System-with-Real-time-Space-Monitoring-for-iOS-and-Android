from __future__ import annotations

from datetime import time

from sqlalchemy import Boolean, ForeignKey, Integer, String, Text, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, foreign, mapped_column, relationship

from app.core.database import Base


class Facility(Base):
    """Reservable facility (e.g., room, device) within a library."""

    __tablename__ = "facilities"
    __table_args__ = (
        UniqueConstraint("library_id", "name", name="uq_facilities_library_name"),
        UniqueConstraint("library_id", "room_code", name="uq_facilities_library_room_code"),
        {"comment": "Reservable spaces/devices available within libraries."},
    )

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, comment="Primary key of the facility."
    )
    library_id: Mapped[int] = mapped_column(
        ForeignKey("libraries.id"),
        nullable=False,
        index=True,
        comment="FK to the parent library.",
    )
    room_no: Mapped[str | None] = mapped_column(
        "room_code",
        String(64),
        nullable=True,
        index=True,
        comment="Stable room number used for booking and AI resolution.",
    )
    facility_type_code: Mapped[str | None] = mapped_column(
        String(32),
        ForeignKey("facility_types.code"),
        nullable=True,
        index=True,
        comment="Stable facility type code used by integrations and AI flows.",
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
    x_coordinate: Mapped[float] = mapped_column(
        default=0.0,
        nullable=False,
        comment="X coordinate for facility placement on map layout.",
    )
    y_coordinate: Mapped[float] = mapped_column(
        default=0.0,
        nullable=False,
        comment="Y coordinate for facility placement on map layout.",
    )
    width: Mapped[float] = mapped_column(
        default=10.0,
        nullable=False,
        comment="Facility width on map layout.",
    )
    height: Mapped[float] = mapped_column(
        default=10.0,
        nullable=False,
        comment="Facility height on map layout.",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        index=True,
        comment="Whether the facility is active and should be shown to users.",
    )
    is_bookable: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        index=True,
        comment="Whether this facility can currently be reserved.",
    )

    library = relationship(
        "Library",
        back_populates="facilities",
        lazy="joined",
        primaryjoin="foreign(Facility.library_id) == Library.id",
    )
    facility_type = relationship(
        "FacilityType",
        back_populates="facilities",
        lazy="joined",
        primaryjoin="foreign(Facility.facility_type_code) == FacilityType.code",
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

    @property
    def room_code(self) -> str | None:
        return self.room_no

    @property
    def resolved_room_no(self) -> str:
        return self.room_no or self.name

    @property
    def resolved_room_code(self) -> str:
        return self.resolved_room_no

    @property
    def resolved_type_code(self) -> str:
        if self.facility_type:
            return self.facility_type.code
        return self.facility_type_code or self.type

