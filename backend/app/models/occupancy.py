from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, Float, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, foreign, mapped_column, relationship

from app.core.database import Base


class OccupancyLog(Base):
    """Logs detailed occupancy results for each analyzed frame/image."""

    __tablename__ = "occupancy_logs"
    __table_args__ = {"comment": "Detailed log of CV analysis results per frame."}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Primary key UUID for the log entry.",
    )
    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
        comment="When this frame/image was processed.",
    )
    location: Mapped[str] = mapped_column(
        String, nullable=True, comment="Library or building name."
    )
    area: Mapped[str] = mapped_column(
        String, nullable=True, comment="Specific floor or zone."
    )
    total_people: Mapped[int] = mapped_column(
        Integer, default=0, nullable=False, comment="Detected person count."
    )
    total_hogging: Mapped[int] = mapped_column(
        Integer, default=0, nullable=False, comment="Detected hogging items count."
    )
    total_seats: Mapped[int] = mapped_column(
        Integer, default=0, nullable=False, comment="Detected seats count."
    )
    occupancy_rate: Mapped[float] = mapped_column(
        Float, default=0.0, nullable=False, comment="Calculated occupancy rate."
    )
    video_source: Mapped[str] = mapped_column(
        String, nullable=True, comment="Source video filename if applicable."
    )
    frame_index: Mapped[int] = mapped_column(
        Integer, nullable=True, comment="Frame index if from video."
    )


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
        Integer,
        nullable=False,
        index=True,
        comment="FK referencing the library being measured (Logical).",
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

    library = relationship(
        "Library",
        back_populates="occupancy_snapshots",
        lazy="joined",
        primaryjoin="foreign(LibraryOccupancySnapshot.library_id) == Library.id",
    )


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
        Integer,
        nullable=False,
        index=True,
        comment="FK referencing the library aggregated (Logical).",
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

    library = relationship(
        "Library",
        back_populates="occupancy_stats",
        lazy="joined",
        primaryjoin="foreign(LibraryOccupancyStatistic.library_id) == Library.id",
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


class AreaOccupancySnapshot(Base):
    __tablename__ = "occupancy_area_snapshots"
    __table_args__ = {"comment": "Near-real-time occupancy snapshots per location+area."}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Primary key UUID for the snapshot.",
    )
    location: Mapped[str] = mapped_column(
        String,
        nullable=False,
        index=True,
        comment="Library or building name.",
    )
    area: Mapped[str] = mapped_column(
        String,
        nullable=False,
        index=True,
        comment="Specific floor or zone.",
    )
    occupancy_rate: Mapped[float] = mapped_column(
        Float, nullable=False, comment="Calculated occupancy ratio (0-1)."
    )
    sample_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, comment="Number of log rows aggregated."
    )
    window_seconds: Mapped[int] = mapped_column(
        Integer, nullable=False, comment="Aggregation window length in seconds."
    )
    measured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
        comment="Timestamp when the snapshot was generated.",
    )


class CameraSource(Base):
    __tablename__ = "camera_sources"
    __table_args__ = {"comment": "Camera streams used for periodic CV ingestion."}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Primary key UUID for the camera source.",
    )
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        unique=True,
        index=True,
        comment="Logical camera identifier.",
    )
    stream_url: Mapped[str] = mapped_column(
        String(1024),
        nullable=False,
        comment="Stream URL (e.g., rtsp/http/file path).",
    )
    location: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
        comment="Library or building name.",
    )
    area: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
        comment="Specific floor or zone.",
    )
    enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        index=True,
        comment="Whether this camera is enabled for ingestion.",
    )
    last_captured_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True,
        comment="Last successful capture timestamp.",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="When this camera source was created.",
    )


