from __future__ import annotations

from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, foreign, mapped_column, relationship

from app.core.database import Base


class FacilityType(Base):
    __tablename__ = "facility_types"
    __table_args__ = {"comment": "Normalized facility type definitions used across booking flows."}

    code: Mapped[str] = mapped_column(
        String(32),
        primary_key=True,
        comment="Stable facility type code used by AI and backend confirmation.",
    )
    name: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        comment="Human readable facility type name.",
    )
    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Optional description for the facility type.",
    )

    facilities = relationship(
        "Facility",
        back_populates="facility_type",
        lazy="noload",
        primaryjoin="FacilityType.code == foreign(Facility.facility_type_code)",
    )
