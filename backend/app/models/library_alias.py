from __future__ import annotations

from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, foreign, mapped_column, relationship

from app.core.database import Base


class LibraryAlias(Base):
    __tablename__ = "library_aliases"
    __table_args__ = (
        UniqueConstraint("alias", name="uq_library_aliases_alias"),
        {"comment": "Alternate names used to resolve libraries from AI and search flows."},
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    library_id: Mapped[int] = mapped_column(
        ForeignKey("libraries.id"),
        nullable=False,
        index=True,
        comment="Parent library id.",
    )
    alias: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
        comment="Alternative display or search alias for a library.",
    )

    library = relationship(
        "Library",
        back_populates="aliases",
        lazy="joined",
        primaryjoin="foreign(LibraryAlias.library_id) == Library.id",
    )
