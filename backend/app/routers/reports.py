from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.reports import (
    ReportBucket,
    ReportHeatmapResponse,
    ReportPeakHoursResponse,
    ReportSummaryResponse,
    ReportTrendResponse,
)
from app.services.report_service import (
    get_report_heatmap,
    get_report_peak_hours,
    get_report_summary,
    get_report_trend,
)

router = APIRouter(prefix="/reports", tags=["Reports"])


def _validate_scope(location: str | None, area: str | None) -> None:
    if area and not location:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="location is required when area is provided.",
        )


@router.get("/summary", response_model=ReportSummaryResponse)
def summary_report(
    location: str | None = Query(default=None, description="Filter by library name."),
    area: str | None = Query(default=None, description="Filter by monitored area."),
    days: int = Query(default=30, ge=1, le=365, description="Lookback window in days."),
    db: Session = Depends(get_db),
) -> ReportSummaryResponse:
    _validate_scope(location, area)
    return get_report_summary(db, location=location, area=area, days=days)


@router.get("/trend", response_model=ReportTrendResponse)
def trend_report(
    location: str | None = Query(default=None, description="Filter by library name."),
    area: str | None = Query(default=None, description="Filter by monitored area."),
    days: int = Query(default=7, ge=1, le=365, description="Lookback window in days."),
    bucket: ReportBucket = Query(default="hour", description="Time bucket for chart points."),
    db: Session = Depends(get_db),
) -> ReportTrendResponse:
    _validate_scope(location, area)
    return get_report_trend(
        db,
        location=location,
        area=area,
        days=days,
        bucket=bucket,
    )


@router.get("/heatmap", response_model=ReportHeatmapResponse)
def heatmap_report(
    location: str | None = Query(default=None, description="Filter by library name."),
    area: str | None = Query(default=None, description="Filter by monitored area."),
    days: int = Query(default=30, ge=1, le=365, description="Lookback window in days."),
    db: Session = Depends(get_db),
) -> ReportHeatmapResponse:
    _validate_scope(location, area)
    return get_report_heatmap(db, location=location, area=area, days=days)


@router.get("/peak-hours", response_model=ReportPeakHoursResponse)
def peak_hours_report(
    location: str | None = Query(default=None, description="Filter by library name."),
    area: str | None = Query(default=None, description="Filter by monitored area."),
    days: int = Query(default=30, ge=1, le=365, description="Lookback window in days."),
    limit: int = Query(default=5, ge=1, le=24, description="Maximum number of time windows."),
    db: Session = Depends(get_db),
) -> ReportPeakHoursResponse:
    _validate_scope(location, area)
    return get_report_peak_hours(
        db,
        location=location,
        area=area,
        days=days,
        limit=limit,
    )
