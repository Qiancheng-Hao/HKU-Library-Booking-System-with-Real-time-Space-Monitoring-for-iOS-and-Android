from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import Integer, Select, cast, desc, func, select
from sqlalchemy.orm import Session

from app.models.occupancy import AreaOccupancySnapshot
from app.schemas.reports import (
    ReportBucket,
    ReportHeatmapCell,
    ReportHeatmapResponse,
    ReportHourInsight,
    ReportPeakHourItem,
    ReportPeakHoursResponse,
    ReportScope,
    ReportSummaryResponse,
    ReportTrendPoint,
    ReportTrendResponse,
    ReportWeekdayInsight,
)

_WEEKDAY_NAMES = {
    0: "Sunday",
    1: "Monday",
    2: "Tuesday",
    3: "Wednesday",
    4: "Thursday",
    5: "Friday",
    6: "Saturday",
}


def _to_percent(value: float | None) -> float | None:
    if value is None:
        return None
    return round(float(value) * 100.0, 2)


def _hour_label(hour: int) -> str:
    start_hour = int(hour) % 24
    end_hour = (start_hour + 1) % 24
    return f"{start_hour:02d}:00-{end_hour:02d}:00"


def _normalize_window(days: int) -> tuple[datetime, datetime]:
    until = datetime.now(timezone.utc)
    since = until - timedelta(days=max(1, int(days)))
    return since, until


def _build_scope(*, location: str | None, area: str | None, days: int, since: datetime, until: datetime) -> ReportScope:
    return ReportScope(
        location=location,
        area=area,
        days=days,
        generatedAt=until,
        since=since,
        until=until,
    )


def _apply_filters(
    stmt: Select,
    *,
    since: datetime,
    until: datetime,
    location: str | None,
    area: str | None,
) -> Select:
    stmt = stmt.where(
        AreaOccupancySnapshot.measured_at >= since,
        AreaOccupancySnapshot.measured_at <= until,
    )
    if location:
        stmt = stmt.where(AreaOccupancySnapshot.location == location)
    if area:
        stmt = stmt.where(AreaOccupancySnapshot.area == area)
    return stmt


def _load_hour_insight(
    db: Session,
    *,
    since: datetime,
    until: datetime,
    location: str | None,
    area: str | None,
    descending: bool,
) -> ReportHourInsight | None:
    hour_expr = cast(func.extract("hour", AreaOccupancySnapshot.measured_at), Integer)
    order_expr = desc("avg_rate") if descending else "avg_rate"
    stmt = (
        select(
            hour_expr.label("hour"),
            func.avg(AreaOccupancySnapshot.occupancy_rate).label("avg_rate"),
            func.max(AreaOccupancySnapshot.occupancy_rate).label("peak_rate"),
            func.sum(AreaOccupancySnapshot.sample_count).label("sample_count"),
        )
        .group_by("hour")
        .having(func.count() > 0)
    )
    stmt = _apply_filters(
        stmt,
        since=since,
        until=until,
        location=location,
        area=area,
    )
    if descending:
        stmt = stmt.order_by(desc("avg_rate"), desc("sample_count"), "hour")
    else:
        stmt = stmt.order_by("avg_rate", desc("sample_count"), "hour")

    row = db.execute(stmt.limit(1)).one_or_none()
    if row is None:
        return None
    return ReportHourInsight(
        hour=int(row.hour),
        label=_hour_label(int(row.hour)),
        averageOccupancyRate=_to_percent(row.avg_rate) or 0.0,
        peakOccupancyRate=_to_percent(row.peak_rate) or 0.0,
        sampleCount=int(row.sample_count or 0),
    )


def _load_busiest_weekday(
    db: Session,
    *,
    since: datetime,
    until: datetime,
    location: str | None,
    area: str | None,
) -> ReportWeekdayInsight | None:
    weekday_expr = cast(func.extract("dow", AreaOccupancySnapshot.measured_at), Integer)
    stmt = (
        select(
            weekday_expr.label("weekday"),
            func.avg(AreaOccupancySnapshot.occupancy_rate).label("avg_rate"),
            func.max(AreaOccupancySnapshot.occupancy_rate).label("peak_rate"),
            func.sum(AreaOccupancySnapshot.sample_count).label("sample_count"),
        )
        .group_by("weekday")
        .having(func.count() > 0)
        .order_by(desc("avg_rate"), desc("sample_count"), "weekday")
    )
    stmt = _apply_filters(
        stmt,
        since=since,
        until=until,
        location=location,
        area=area,
    )

    row = db.execute(stmt.limit(1)).one_or_none()
    if row is None:
        return None

    weekday = int(row.weekday)
    return ReportWeekdayInsight(
        weekdayIndex=weekday,
        weekdayName=_WEEKDAY_NAMES.get(weekday, f"Day {weekday}"),
        averageOccupancyRate=_to_percent(row.avg_rate) or 0.0,
        peakOccupancyRate=_to_percent(row.peak_rate) or 0.0,
        sampleCount=int(row.sample_count or 0),
    )


def get_report_summary(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
) -> ReportSummaryResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(location=location, area=area, days=days, since=since, until=until)
    stmt = select(
        func.avg(AreaOccupancySnapshot.occupancy_rate).label("avg_rate"),
        func.max(AreaOccupancySnapshot.occupancy_rate).label("peak_rate"),
        func.sum(AreaOccupancySnapshot.sample_count).label("total_samples"),
        func.count().label("observation_count"),
        func.min(AreaOccupancySnapshot.measured_at).label("first_observed_at"),
        func.max(AreaOccupancySnapshot.measured_at).label("last_observed_at"),
    )
    stmt = _apply_filters(
        stmt,
        since=since,
        until=until,
        location=location,
        area=area,
    )
    row = db.execute(stmt).one()
    has_data = bool(row.observation_count)
    if not has_data:
        return ReportSummaryResponse(scope=scope, hasData=False)

    return ReportSummaryResponse(
        scope=scope,
        hasData=True,
        averageOccupancyRate=_to_percent(row.avg_rate),
        peakOccupancyRate=_to_percent(row.peak_rate),
        totalSampleCount=int(row.total_samples or 0),
        observationCount=int(row.observation_count or 0),
        firstObservedAt=row.first_observed_at,
        lastObservedAt=row.last_observed_at,
        busiestWeekday=_load_busiest_weekday(
            db,
            since=since,
            until=until,
            location=location,
            area=area,
        ),
        busiestHour=_load_hour_insight(
            db,
            since=since,
            until=until,
            location=location,
            area=area,
            descending=True,
        ),
        suggestedLowTrafficHour=_load_hour_insight(
            db,
            since=since,
            until=until,
            location=location,
            area=area,
            descending=False,
        ),
    )


def get_report_trend(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
    bucket: ReportBucket,
) -> ReportTrendResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(location=location, area=area, days=days, since=since, until=until)
    trunc_unit = "hour" if bucket == "hour" else "day"
    bucket_expr = func.date_trunc(trunc_unit, AreaOccupancySnapshot.measured_at)
    stmt = (
        select(
            bucket_expr.label("bucket_start"),
            func.avg(AreaOccupancySnapshot.occupancy_rate).label("avg_rate"),
            func.max(AreaOccupancySnapshot.occupancy_rate).label("peak_rate"),
            func.sum(AreaOccupancySnapshot.sample_count).label("sample_count"),
        )
        .group_by("bucket_start")
        .order_by("bucket_start")
    )
    stmt = _apply_filters(
        stmt,
        since=since,
        until=until,
        location=location,
        area=area,
    )
    rows = db.execute(stmt).all()
    points = [
        ReportTrendPoint(
            bucketStart=row.bucket_start,
            bucketLabel=row.bucket_start.strftime("%Y-%m-%d %H:%M" if bucket == "hour" else "%Y-%m-%d"),
            averageOccupancyRate=_to_percent(row.avg_rate) or 0.0,
            peakOccupancyRate=_to_percent(row.peak_rate) or 0.0,
            sampleCount=int(row.sample_count or 0),
        )
        for row in rows
    ]
    return ReportTrendResponse(scope=scope, bucket=bucket, points=points)


def get_report_heatmap(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
) -> ReportHeatmapResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(location=location, area=area, days=days, since=since, until=until)
    weekday_expr = cast(func.extract("dow", AreaOccupancySnapshot.measured_at), Integer)
    hour_expr = cast(func.extract("hour", AreaOccupancySnapshot.measured_at), Integer)
    stmt = (
        select(
            weekday_expr.label("weekday"),
            hour_expr.label("hour"),
            func.avg(AreaOccupancySnapshot.occupancy_rate).label("avg_rate"),
            func.max(AreaOccupancySnapshot.occupancy_rate).label("peak_rate"),
            func.sum(AreaOccupancySnapshot.sample_count).label("sample_count"),
        )
        .group_by("weekday", "hour")
        .order_by("weekday", "hour")
    )
    stmt = _apply_filters(
        stmt,
        since=since,
        until=until,
        location=location,
        area=area,
    )
    rows = db.execute(stmt).all()
    cells = [
        ReportHeatmapCell(
            weekdayIndex=int(row.weekday),
            weekdayName=_WEEKDAY_NAMES.get(int(row.weekday), f"Day {int(row.weekday)}"),
            hour=int(row.hour),
            averageOccupancyRate=_to_percent(row.avg_rate) or 0.0,
            peakOccupancyRate=_to_percent(row.peak_rate) or 0.0,
            sampleCount=int(row.sample_count or 0),
        )
        for row in rows
    ]
    return ReportHeatmapResponse(scope=scope, cells=cells)


def get_report_peak_hours(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
    limit: int,
) -> ReportPeakHoursResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(location=location, area=area, days=days, since=since, until=until)
    hour_expr = cast(func.extract("hour", AreaOccupancySnapshot.measured_at), Integer)
    stmt = (
        select(
            hour_expr.label("hour"),
            func.avg(AreaOccupancySnapshot.occupancy_rate).label("avg_rate"),
            func.max(AreaOccupancySnapshot.occupancy_rate).label("peak_rate"),
            func.sum(AreaOccupancySnapshot.sample_count).label("sample_count"),
        )
        .group_by("hour")
        .having(func.count() > 0)
        .order_by(desc("avg_rate"), desc("sample_count"), "hour")
        .limit(max(1, int(limit)))
    )
    stmt = _apply_filters(
        stmt,
        since=since,
        until=until,
        location=location,
        area=area,
    )
    rows = db.execute(stmt).all()
    items = [
        ReportPeakHourItem(
            rank=index,
            hour=int(row.hour),
            label=_hour_label(int(row.hour)),
            averageOccupancyRate=_to_percent(row.avg_rate) or 0.0,
            peakOccupancyRate=_to_percent(row.peak_rate) or 0.0,
            sampleCount=int(row.sample_count or 0),
        )
        for index, row in enumerate(rows, start=1)
    ]
    return ReportPeakHoursResponse(scope=scope, items=items)
