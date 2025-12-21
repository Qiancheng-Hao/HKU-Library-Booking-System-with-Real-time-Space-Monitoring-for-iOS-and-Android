from __future__ import annotations

import uuid

from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class User(Base):
    """Represents an end user who can place reservations."""

    __tablename__ = "users"
    __table_args__ = {"comment": "End users who can make facility reservations."}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="Primary key UUID for the user.",
    )
    full_name: Mapped[str] = mapped_column(
        String(255), nullable=False, comment="User full name as provided."
    )
    email: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        unique=True,
        index=True,
        comment="Unique email used for booking identification.",
    )

    reservations = relationship(
        "Reservation",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="noload",
    )

