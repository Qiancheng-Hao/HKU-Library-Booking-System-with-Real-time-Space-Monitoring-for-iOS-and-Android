from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Integer, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class OccupancyPeriod(str, enum.Enum):
    """Supported aggregation periods for occupancy statistics."""

    hourly = "hourly"
    daily = "daily"
    weekly = "weekly"


class LibraryOccupancySnapshot(Base):
    """Stores near-real-time occupancy data per library."""

    __tablename__ = "library_occupancy_snapshots"
    __table_args__ = {"comment": "Raw occupancy snapshots captured every few minutes."}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Primary key UUID for the snapshot.",
    )
    library_id: Mapped[int] = mapped_column(
        ForeignKey("libraries.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="FK referencing the library being measured.",
    )
    seats_capacity: Mapped[int] = mapped_column(
        Integer, nullable=False, comment="Total seats considered during measurement."
    )
    seats_occupied: Mapped[int] = mapped_column(
        Integer, nullable=False, comment="Number of seats in use."
    )
    occupancy_rate: Mapped[float] = mapped_column(
        Float, nullable=False, comment="Calculated occupancy ratio (0-1)."
    )
    measured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
        comment="Timestamp when the sample was taken.",
    )
    refresh_interval: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=5,
        comment="Expected refresh interval in minutes.",
        doc="Refresh interval in minutes.",
    )

    library = relationship("Library", back_populates="occupancy_snapshots", lazy="joined")


class LibraryOccupancyStatistic(Base):
    """Aggregated occupancy metrics for periodic insights."""

    __tablename__ = "library_occupancy_statistics"
    __table_args__ = {"comment": "Aggregated occupancy metrics over standard periods."}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Primary key UUID for the aggregated record.",
    )
    library_id: Mapped[int] = mapped_column(
        ForeignKey("libraries.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="FK referencing the library aggregated.",
    )
    period_type: Mapped[OccupancyPeriod] = mapped_column(
        Enum(OccupancyPeriod, name="occupancy_period"),
        nullable=False,
        default=OccupancyPeriod.daily,
        comment="Aggregation cadence (hourly/daily/weekly).",
    )
    period_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="Start timestamp of the aggregation window.",
    )
    period_end: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="End timestamp of the aggregation window.",
    )
    average_rate: Mapped[float] = mapped_column(
        Float, nullable=False, comment="Average occupancy rate for the window."
    )
    peak_rate: Mapped[float] = mapped_column(
        Float, nullable=False, comment="Highest occupancy rate observed."
    )
    sample_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, comment="Number of snapshots aggregated."
    )
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="Timestamp when this aggregate was generated.",
    )
    window_minutes: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        comment="Optional custom rolling window length (minutes).",
        doc="Optional aggregation window size in minutes.",
    )

    library = relationship("Library", back_populates="occupancy_stats", lazy="joined")

