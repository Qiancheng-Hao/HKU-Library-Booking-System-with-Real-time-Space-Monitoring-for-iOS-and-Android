from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class AISession(Base):
    __tablename__ = "ai_sessions"
    __table_args__ = {"comment": "Backend-managed AI session mapping and confirmation state."}

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    ai_session_id: Mapped[str] = mapped_column(
        String(64),
        unique=True,
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
    )
    upstream_session_id: Mapped[str] = mapped_column(
        String(64),
        unique=True,
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        default="active",
        nullable=False,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_message_summary: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )
    last_intent_hash: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True,
    )
    last_confirmed_intent_hash: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True,
    )
    last_confirm_result: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
    )
