from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.models import Facility, Library
from app.schemas.library import (
    LibraryDetailResponse,
    LibraryListResponse,
    LibrarySummary,
)

router = APIRouter(prefix="/libraries", tags=["Libraries"])


@router.get("", response_model=LibraryListResponse)
def list_libraries(db: Session = Depends(get_db)) -> LibraryListResponse:
    stmt = (
        select(
            Library.id,
            Library.name,
            Library.location,
            func.count(Facility.id).label("facility_count"),
        )
        .outerjoin(Facility, Library.id == Facility.library_id)
        .group_by(Library.id)
        .order_by(Library.name.asc())
    )

    rows = db.execute(stmt).all()
    items = [
        LibrarySummary(
            id=row.id,
            name=row.name,
            location=row.location,
            facility_count=row.facility_count,
        )
        for row in rows
    ]
    return LibraryListResponse(items=items, total=len(items))


@router.get("/{library_id}", response_model=LibraryDetailResponse)
def get_library(library_id: int, db: Session = Depends(get_db)) -> LibraryDetailResponse:
    stmt = (
        select(Library)
        .options(selectinload(Library.facilities))
        .where(Library.id == library_id)
    )
    library = db.execute(stmt).scalar_one_or_none()
    if not library:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Library not found.",
        )

    return LibraryDetailResponse(library=library)

