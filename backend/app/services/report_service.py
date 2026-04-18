from __future__ import annotations

import logging
import re
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import Integer, Select, cast, desc, func, select, text
from sqlalchemy.orm import Session

from app.core.config import settings
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

logger = logging.getLogger(__name__)

_WEEKDAY_NAMES = {
    0: "Sunday",
    1: "Monday",
    2: "Tuesday",
    3: "Wednesday",
    4: "Thursday",
    5: "Friday",
    6: "Saturday",
}

_REPORT_TZ = ZoneInfo(settings.default_timezone)


def _sanitize_identifier(value: str, default_value: str) -> str:
    candidate = (value or "").strip()
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", candidate):
        return candidate
    return default_value


_REPORTS_30M_VIEW = _sanitize_identifier(
    settings.occupancy_reports_30m_view_name,
    "occupancy_reports_30m",
)
_REPORTS_1H_VIEW = _sanitize_identifier(
    settings.occupancy_reports_1h_view_name,
    "occupancy_reports_1h",
)


def _to_percent(value: float | None) -> float | None:
    if value is None:
        return None
    return round(float(value) * 100.0, 2)


def _hour_label(hour: int) -> str:
    start_hour = int(hour) % 24
    end_hour = (start_hour + 1) % 24
    return f"{start_hour:02d}:00-{end_hour:02d}:00"


def _normalize_window(days: int) -> tuple[datetime, datetime]:
    until = datetime.now(_REPORT_TZ)
    since = until - timedelta(days=max(1, int(days)))
    return since, until


def _local_measured_at_expr():
    return func.timezone(
        settings.default_timezone,
        AreaOccupancySnapshot.measured_at,
    )


def _as_report_time(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=_REPORT_TZ)
    return value.astimezone(_REPORT_TZ)


def _build_scope(
    *,
    location: str | None,
    area: str | None,
    days: int,
    since: datetime,
    until: datetime,
) -> ReportScope:
    return ReportScope(
        location=location,
        area=area,
        days=days,
        generatedAt=_as_report_time(until),
        since=_as_report_time(since),
        until=_as_report_time(until),
    )


def _bucket_label(bucket_start: datetime, bucket: ReportBucket) -> str:
    label_format = "%Y-%m-%d %H:%M" if bucket == "hour" else "%Y-%m-%d"
    return bucket_start.strftime(label_format)


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


def _view_exists(db: Session, view_name: str) -> bool:
    stmt = text(
        "SELECT EXISTS("
        "SELECT 1 FROM pg_matviews "
        "WHERE schemaname = 'public' AND matviewname = :view_name"
        ")"
    )
    return bool(db.execute(stmt, {"view_name": view_name}).scalar())


def _view_query_parts(
    *,
    since: datetime,
    until: datetime,
    location: str | None,
    area: str | None,
) -> tuple[str, dict[str, object]]:
    conditions = ["bucket >= :since", "bucket <= :until"]
    params: dict[str, object] = {
        "since": since,
        "until": until,
        "tz_name": settings.default_timezone,
    }
    if location:
        conditions.append("location = :location")
        params["location"] = location
    if area:
        conditions.append("area = :area")
        params["area"] = area
    return " AND ".join(conditions), params


def _weighted_avg_sql(value_column: str, weight_column: str = "observation_count") -> str:
    return (
        f"SUM({value_column} * {weight_column}) / "
        f"NULLIF(SUM({weight_column}), 0)"
    )


def _load_raw_hour_insight(
    db: Session,
    *,
    since: datetime,
    until: datetime,
    location: str | None,
    area: str | None,
    descending: bool,
) -> ReportHourInsight | None:
    hour_expr = cast(func.extract("hour", _local_measured_at_expr()), Integer)
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


def _load_raw_busiest_weekday(
    db: Session,
    *,
    since: datetime,
    until: datetime,
    location: str | None,
    area: str | None,
) -> ReportWeekdayInsight | None:
    weekday_expr = cast(func.extract("dow", _local_measured_at_expr()), Integer)
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


def _get_report_summary_raw(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
) -> ReportSummaryResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(
        location=location,
        area=area,
        days=days,
        since=since,
        until=until,
    )
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
    if not bool(row.observation_count):
        return ReportSummaryResponse(scope=scope, hasData=False)
    return ReportSummaryResponse(
        scope=scope,
        hasData=True,
        averageOccupancyRate=_to_percent(row.avg_rate),
        peakOccupancyRate=_to_percent(row.peak_rate),
        totalSampleCount=int(row.total_samples or 0),
        observationCount=int(row.observation_count or 0),
        firstObservedAt=_as_report_time(row.first_observed_at),
        lastObservedAt=_as_report_time(row.last_observed_at),
        busiestWeekday=_load_raw_busiest_weekday(
            db,
            since=since,
            until=until,
            location=location,
            area=area,
        ),
        busiestHour=_load_raw_hour_insight(
            db,
            since=since,
            until=until,
            location=location,
            area=area,
            descending=True,
        ),
        suggestedLowTrafficHour=_load_raw_hour_insight(
            db,
            since=since,
            until=until,
            location=location,
            area=area,
            descending=False,
        ),
    )


def _get_report_trend_raw(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
    bucket: ReportBucket,
) -> ReportTrendResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(
        location=location,
        area=area,
        days=days,
        since=since,
        until=until,
    )
    trunc_unit = "hour" if bucket == "hour" else "day"
    bucket_expr = func.date_trunc(trunc_unit, _local_measured_at_expr())
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
    points: list[ReportTrendPoint] = []
    for row in rows:
        bucket_start = _as_report_time(row.bucket_start)
        if bucket_start is None:
            continue
        points.append(
            ReportTrendPoint(
                bucketStart=bucket_start,
                bucketLabel=_bucket_label(bucket_start, bucket),
                averageOccupancyRate=_to_percent(row.avg_rate) or 0.0,
                peakOccupancyRate=_to_percent(row.peak_rate) or 0.0,
                sampleCount=int(row.sample_count or 0),
            )
        )
    return ReportTrendResponse(scope=scope, bucket=bucket, points=points)


def _get_report_heatmap_raw(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
) -> ReportHeatmapResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(
        location=location,
        area=area,
        days=days,
        since=since,
        until=until,
    )
    weekday_expr = cast(func.extract("dow", _local_measured_at_expr()), Integer)
    hour_expr = cast(func.extract("hour", _local_measured_at_expr()), Integer)
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
    return ReportHeatmapResponse(
        scope=scope,
        cells=[
            ReportHeatmapCell(
                weekdayIndex=int(row.weekday),
                weekdayName=_WEEKDAY_NAMES.get(int(row.weekday), f"Day {int(row.weekday)}"),
                hour=int(row.hour),
                averageOccupancyRate=_to_percent(row.avg_rate) or 0.0,
                peakOccupancyRate=_to_percent(row.peak_rate) or 0.0,
                sampleCount=int(row.sample_count or 0),
            )
            for row in rows
        ],
    )


def _get_report_peak_hours_raw(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
    limit: int,
) -> ReportPeakHoursResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(
        location=location,
        area=area,
        days=days,
        since=since,
        until=until,
    )
    hour_expr = cast(func.extract("hour", _local_measured_at_expr()), Integer)
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
    return ReportPeakHoursResponse(
        scope=scope,
        items=[
            ReportPeakHourItem(
                rank=index,
                hour=int(row.hour),
                label=_hour_label(int(row.hour)),
                averageOccupancyRate=_to_percent(row.avg_rate) or 0.0,
                peakOccupancyRate=_to_percent(row.peak_rate) or 0.0,
                sampleCount=int(row.sample_count or 0),
            )
            for index, row in enumerate(rows, start=1)
        ],
    )


def _load_view_hour_insight(
    db: Session,
    *,
    view_name: str,
    since: datetime,
    until: datetime,
    location: str | None,
    area: str | None,
    descending: bool,
) -> ReportHourInsight | None:
    where_sql, params = _view_query_parts(
        since=since,
        until=until,
        location=location,
        area=area,
    )
    direction = "DESC" if descending else "ASC"
    stmt = text(
        f"""
        SELECT
            EXTRACT(HOUR FROM timezone(:tz_name, bucket))::int AS hour,
            {_weighted_avg_sql("avg_occupancy_rate")} AS avg_rate,
            MAX(peak_occupancy_rate) AS peak_rate,
            SUM(total_samples) AS sample_count,
            SUM(observation_count) AS observation_count
        FROM {view_name}
        WHERE {where_sql}
        GROUP BY hour
        HAVING SUM(observation_count) > 0
        ORDER BY avg_rate {direction}, sample_count DESC, hour
        LIMIT 1
        """
    )
    row = db.execute(stmt, params).mappings().one_or_none()
    if row is None:
        return None
    hour = int(row["hour"])
    return ReportHourInsight(
        hour=hour,
        label=_hour_label(hour),
        averageOccupancyRate=_to_percent(row["avg_rate"]) or 0.0,
        peakOccupancyRate=_to_percent(row["peak_rate"]) or 0.0,
        sampleCount=int(row["sample_count"] or 0),
    )


def _load_view_busiest_weekday(
    db: Session,
    *,
    view_name: str,
    since: datetime,
    until: datetime,
    location: str | None,
    area: str | None,
) -> ReportWeekdayInsight | None:
    where_sql, params = _view_query_parts(
        since=since,
        until=until,
        location=location,
        area=area,
    )
    stmt = text(
        f"""
        SELECT
            EXTRACT(DOW FROM timezone(:tz_name, bucket))::int AS weekday,
            {_weighted_avg_sql("avg_occupancy_rate")} AS avg_rate,
            MAX(peak_occupancy_rate) AS peak_rate,
            SUM(total_samples) AS sample_count,
            SUM(observation_count) AS observation_count
        FROM {view_name}
        WHERE {where_sql}
        GROUP BY weekday
        HAVING SUM(observation_count) > 0
        ORDER BY avg_rate DESC, sample_count DESC, weekday
        LIMIT 1
        """
    )
    row = db.execute(stmt, params).mappings().one_or_none()
    if row is None:
        return None
    weekday = int(row["weekday"])
    return ReportWeekdayInsight(
        weekdayIndex=weekday,
        weekdayName=_WEEKDAY_NAMES.get(weekday, f"Day {weekday}"),
        averageOccupancyRate=_to_percent(row["avg_rate"]) or 0.0,
        peakOccupancyRate=_to_percent(row["peak_rate"]) or 0.0,
        sampleCount=int(row["sample_count"] or 0),
    )


def _get_report_summary_from_view(
    db: Session,
    *,
    view_name: str,
    location: str | None,
    area: str | None,
    days: int,
) -> ReportSummaryResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(
        location=location,
        area=area,
        days=days,
        since=since,
        until=until,
    )
    where_sql, params = _view_query_parts(
        since=since,
        until=until,
        location=location,
        area=area,
    )
    stmt = text(
        f"""
        SELECT
            {_weighted_avg_sql("avg_occupancy_rate")} AS avg_rate,
            MAX(peak_occupancy_rate) AS peak_rate,
            SUM(total_samples) AS total_samples,
            SUM(observation_count) AS observation_count,
            MIN(first_observed_at) AS first_observed_at,
            MAX(last_observed_at) AS last_observed_at
        FROM {view_name}
        WHERE {where_sql}
        """
    )
    row = db.execute(stmt, params).mappings().one()
    if not bool(row["observation_count"]):
        return ReportSummaryResponse(scope=scope, hasData=False)
    return ReportSummaryResponse(
        scope=scope,
        hasData=True,
        averageOccupancyRate=_to_percent(row["avg_rate"]),
        peakOccupancyRate=_to_percent(row["peak_rate"]),
        totalSampleCount=int(row["total_samples"] or 0),
        observationCount=int(row["observation_count"] or 0),
        firstObservedAt=_as_report_time(row["first_observed_at"]),
        lastObservedAt=_as_report_time(row["last_observed_at"]),
        busiestWeekday=_load_view_busiest_weekday(
            db,
            view_name=view_name,
            since=since,
            until=until,
            location=location,
            area=area,
        ),
        busiestHour=_load_view_hour_insight(
            db,
            view_name=view_name,
            since=since,
            until=until,
            location=location,
            area=area,
            descending=True,
        ),
        suggestedLowTrafficHour=_load_view_hour_insight(
            db,
            view_name=view_name,
            since=since,
            until=until,
            location=location,
            area=area,
            descending=False,
        ),
    )


def _get_report_trend_from_view(
    db: Session,
    *,
    view_name: str,
    location: str | None,
    area: str | None,
    days: int,
    bucket: ReportBucket,
) -> ReportTrendResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(
        location=location,
        area=area,
        days=days,
        since=since,
        until=until,
    )
    trunc_unit = "hour" if bucket == "hour" else "day"
    where_sql, params = _view_query_parts(
        since=since,
        until=until,
        location=location,
        area=area,
    )
    stmt = text(
        f"""
        SELECT
            date_trunc('{trunc_unit}', timezone(:tz_name, bucket)) AS bucket_start,
            {_weighted_avg_sql("avg_occupancy_rate")} AS avg_rate,
            MAX(peak_occupancy_rate) AS peak_rate,
            SUM(total_samples) AS sample_count,
            SUM(observation_count) AS observation_count
        FROM {view_name}
        WHERE {where_sql}
        GROUP BY bucket_start
        HAVING SUM(observation_count) > 0
        ORDER BY bucket_start
        """
    )
    rows = db.execute(stmt, params).mappings().all()
    points: list[ReportTrendPoint] = []
    for row in rows:
        bucket_start = _as_report_time(row["bucket_start"])
        if bucket_start is None:
            continue
        points.append(
            ReportTrendPoint(
                bucketStart=bucket_start,
                bucketLabel=_bucket_label(bucket_start, bucket),
                averageOccupancyRate=_to_percent(row["avg_rate"]) or 0.0,
                peakOccupancyRate=_to_percent(row["peak_rate"]) or 0.0,
                sampleCount=int(row["sample_count"] or 0),
            )
        )
    return ReportTrendResponse(scope=scope, bucket=bucket, points=points)


def _get_report_heatmap_from_view(
    db: Session,
    *,
    view_name: str,
    location: str | None,
    area: str | None,
    days: int,
) -> ReportHeatmapResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(
        location=location,
        area=area,
        days=days,
        since=since,
        until=until,
    )
    where_sql, params = _view_query_parts(
        since=since,
        until=until,
        location=location,
        area=area,
    )
    stmt = text(
        f"""
        SELECT
            EXTRACT(DOW FROM timezone(:tz_name, bucket))::int AS weekday,
            EXTRACT(HOUR FROM timezone(:tz_name, bucket))::int AS hour,
            {_weighted_avg_sql("avg_occupancy_rate")} AS avg_rate,
            MAX(peak_occupancy_rate) AS peak_rate,
            SUM(total_samples) AS sample_count,
            SUM(observation_count) AS observation_count
        FROM {view_name}
        WHERE {where_sql}
        GROUP BY weekday, hour
        HAVING SUM(observation_count) > 0
        ORDER BY weekday, hour
        """
    )
    rows = db.execute(stmt, params).mappings().all()
    return ReportHeatmapResponse(
        scope=scope,
        cells=[
            ReportHeatmapCell(
                weekdayIndex=int(row["weekday"]),
                weekdayName=_WEEKDAY_NAMES.get(int(row["weekday"]), f"Day {int(row['weekday'])}"),
                hour=int(row["hour"]),
                averageOccupancyRate=_to_percent(row["avg_rate"]) or 0.0,
                peakOccupancyRate=_to_percent(row["peak_rate"]) or 0.0,
                sampleCount=int(row["sample_count"] or 0),
            )
            for row in rows
        ],
    )


def _get_report_peak_hours_from_view(
    db: Session,
    *,
    view_name: str,
    location: str | None,
    area: str | None,
    days: int,
    limit: int,
) -> ReportPeakHoursResponse:
    since, until = _normalize_window(days)
    scope = _build_scope(
        location=location,
        area=area,
        days=days,
        since=since,
        until=until,
    )
    where_sql, params = _view_query_parts(
        since=since,
        until=until,
        location=location,
        area=area,
    )
    params["limit"] = max(1, int(limit))
    stmt = text(
        f"""
        SELECT
            EXTRACT(HOUR FROM timezone(:tz_name, bucket))::int AS hour,
            {_weighted_avg_sql("avg_occupancy_rate")} AS avg_rate,
            MAX(peak_occupancy_rate) AS peak_rate,
            SUM(total_samples) AS sample_count,
            SUM(observation_count) AS observation_count
        FROM {view_name}
        WHERE {where_sql}
        GROUP BY hour
        HAVING SUM(observation_count) > 0
        ORDER BY avg_rate DESC, sample_count DESC, hour
        LIMIT :limit
        """
    )
    rows = db.execute(stmt, params).mappings().all()
    return ReportPeakHoursResponse(
        scope=scope,
        items=[
            ReportPeakHourItem(
                rank=index,
                hour=int(row["hour"]),
                label=_hour_label(int(row["hour"])),
                averageOccupancyRate=_to_percent(row["avg_rate"]) or 0.0,
                peakOccupancyRate=_to_percent(row["peak_rate"]) or 0.0,
                sampleCount=int(row["sample_count"] or 0),
            )
            for index, row in enumerate(rows, start=1)
        ],
    )


def get_report_summary(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
) -> ReportSummaryResponse:
    if settings.occupancy_reports_aggregates_enabled and _view_exists(db, _REPORTS_1H_VIEW):
        try:
            result = _get_report_summary_from_view(
                db,
                view_name=_REPORTS_1H_VIEW,
                location=location,
                area=area,
                days=days,
            )
            if result.hasData:
                return result
        except Exception:
            logger.exception("summary report aggregate query failed, falling back to raw snapshots")
    return _get_report_summary_raw(
        db,
        location=location,
        area=area,
        days=days,
    )


def get_report_trend(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
    bucket: ReportBucket,
) -> ReportTrendResponse:
    if settings.occupancy_reports_aggregates_enabled and _view_exists(db, _REPORTS_30M_VIEW):
        try:
            result = _get_report_trend_from_view(
                db,
                view_name=_REPORTS_30M_VIEW,
                location=location,
                area=area,
                days=days,
                bucket=bucket,
            )
            if result.points:
                return result
        except Exception:
            logger.exception("trend report aggregate query failed, falling back to raw snapshots")
    return _get_report_trend_raw(
        db,
        location=location,
        area=area,
        days=days,
        bucket=bucket,
    )


def get_report_heatmap(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
) -> ReportHeatmapResponse:
    if settings.occupancy_reports_aggregates_enabled and _view_exists(db, _REPORTS_1H_VIEW):
        try:
            result = _get_report_heatmap_from_view(
                db,
                view_name=_REPORTS_1H_VIEW,
                location=location,
                area=area,
                days=days,
            )
            if result.cells:
                return result
        except Exception:
            logger.exception("heatmap report aggregate query failed, falling back to raw snapshots")
    return _get_report_heatmap_raw(
        db,
        location=location,
        area=area,
        days=days,
    )


def get_report_peak_hours(
    db: Session,
    *,
    location: str | None,
    area: str | None,
    days: int,
    limit: int,
) -> ReportPeakHoursResponse:
    if settings.occupancy_reports_aggregates_enabled and _view_exists(db, _REPORTS_1H_VIEW):
        try:
            result = _get_report_peak_hours_from_view(
                db,
                view_name=_REPORTS_1H_VIEW,
                location=location,
                area=area,
                days=days,
                limit=limit,
            )
            if result.items:
                return result
        except Exception:
            logger.exception("peak-hours report aggregate query failed, falling back to raw snapshots")
    return _get_report_peak_hours_raw(
        db,
        location=location,
        area=area,
        days=days,
        limit=limit,
    )
