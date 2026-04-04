from __future__ import annotations

from sqlalchemy import Float, Integer, String, Text
from sqlalchemy.orm import Mapped, foreign, mapped_column, relationship

from app.core.database import Base


class Library(Base):
    """Represents a physical library location."""

    __tablename__ = "libraries"
    __table_args__ = {"comment": "Master list of HKU libraries and their contact info."}

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, comment="Primary key of the library."
    )
    legacy_code: Mapped[str | None] = mapped_column(
        String(32),
        unique=True,
        index=True,
        nullable=True,
        comment="Legacy upstream library code used by historical AI mappings.",
    )
    name: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        comment="Human readable library name.",
    )
    location: Mapped[str | None] = mapped_column(
        String(255), nullable=True, comment="Physical address or campus location."
    )
    campus: Mapped[str | None] = mapped_column(
        String(255), nullable=True, comment="Broad campus classification (e.g., Centennial Campus)."
    )
    description: Mapped[str | None] = mapped_column(
        Text, nullable=True, comment="Long-form description of facilities or services."
    )
    opening_hours: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True,
        comment="Opening hours for the day (e.g., 08:00-22:00).",
    )
    latitude: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Latitude used for location and routing experiences.",
    )
    longitude: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        comment="Longitude used for location and routing experiences.",
    )
    facilities = relationship(
        "Facility",
        back_populates="library",
        cascade="all, delete-orphan",
        lazy="selectin",
        primaryjoin="Library.id == foreign(Facility.library_id)",
    )
    aliases = relationship(
        "LibraryAlias",
        back_populates="library",
        cascade="all, delete-orphan",
        lazy="selectin",
        primaryjoin="Library.id == foreign(LibraryAlias.library_id)",
    )
    # occupancy_snapshots = relationship(
    #     "LibraryOccupancySnapshot",
    #     back_populates="library",
    #     cascade="all, delete-orphan",
    #     lazy="noload",
    #     primaryjoin="Library.id == foreign(LibraryOccupancySnapshot.library_id)",
    # )
    # occupancy_stats = relationship(
    #     "LibraryOccupancyStatistic",
    #     back_populates="library",
    #     cascade="all, delete-orphan",
    #     lazy="noload",
    #     primaryjoin="Library.id == foreign(LibraryOccupancyStatistic.library_id)",
    # )

