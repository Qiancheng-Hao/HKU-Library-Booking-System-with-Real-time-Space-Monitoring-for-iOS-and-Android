from __future__ import annotations

import logging
import re
from datetime import datetime, timezone

from sqlalchemy import text

from app.core.config import settings
from app.core.database import engine

logger = logging.getLogger(__name__)

_INIT_STATE: dict[str, object] = {
    "checked_at": None,
    "base_schema_ready": False,
    "timescale_enabled": False,
    "timescale_initialized": False,
    "error": None,
}


def _is_postgresql() -> bool:
    return engine.dialect.name == "postgresql"


def _sanitize_interval(value: str, default_value: str) -> str:
    candidate = (value or "").strip()
    if re.fullmatch(r"[0-9A-Za-z _-]+", candidate):
        return candidate
    return default_value


def _run_statement(sql: str) -> None:
    with engine.begin() as connection:
        connection.execute(text(sql))


def _run_scalar(sql: str):
    with engine.begin() as connection:
        return connection.execute(text(sql)).scalar_one_or_none()


def _ensure_base_occupancy_schema() -> None:
    statements = [
        "ALTER TABLE occupancy_logs ADD COLUMN IF NOT EXISTS event_id UUID",
        "ALTER TABLE occupancy_logs ADD COLUMN IF NOT EXISTS camera_name VARCHAR",
        "DROP INDEX IF EXISTS ux_occupancy_logs_event_id",
        "CREATE UNIQUE INDEX IF NOT EXISTS ux_occupancy_logs_captured_event ON occupancy_logs (captured_at, event_id) WHERE event_id IS NOT NULL",
        "CREATE UNIQUE INDEX IF NOT EXISTS ux_occupancy_area_snapshots_window ON occupancy_area_snapshots (location, area, measured_at, window_seconds)",
    ]
    for statement in statements:
        _run_statement(statement)


def _configure_timescaledb() -> None:
    log_chunk_interval = _sanitize_interval(
        settings.occupancy_log_chunk_interval,
        "1 day",
    )
    snapshot_chunk_interval = _sanitize_interval(
        settings.occupancy_snapshot_chunk_interval,
        "7 days",
    )
    log_retention_days = max(1, int(settings.occupancy_log_retention_days))
    snapshot_retention_days = max(1, int(settings.occupancy_snapshot_retention_days))
    log_compression_after_days = max(1, int(settings.occupancy_log_compression_after_days))
    snapshot_compression_after_days = max(
        1,
        int(settings.occupancy_snapshot_compression_after_days),
    )

    statements = [
        "CREATE EXTENSION IF NOT EXISTS timescaledb",
        (
            "SELECT create_hypertable("
            "'occupancy_logs', 'captured_at', "
            f"chunk_time_interval => INTERVAL '{log_chunk_interval}', "
            "if_not_exists => TRUE"
            ")"
        ),
        (
            "SELECT create_hypertable("
            "'occupancy_area_snapshots', 'measured_at', "
            f"chunk_time_interval => INTERVAL '{snapshot_chunk_interval}', "
            "if_not_exists => TRUE"
            ")"
        ),
        (
            "ALTER TABLE occupancy_logs SET ("
            "timescaledb.compress,"
            "timescaledb.compress_segmentby = 'location, area, camera_name'"
            ")"
        ),
        (
            "ALTER TABLE occupancy_area_snapshots SET ("
            "timescaledb.compress,"
            "timescaledb.compress_segmentby = 'location, area'"
            ")"
        ),
        (
            "SELECT add_retention_policy("
            "'occupancy_logs', "
            f"INTERVAL '{log_retention_days} days', "
            "if_not_exists => TRUE"
            ")"
        ),
        (
            "SELECT add_retention_policy("
            "'occupancy_area_snapshots', "
            f"INTERVAL '{snapshot_retention_days} days', "
            "if_not_exists => TRUE"
            ")"
        ),
        (
            "SELECT add_compression_policy("
            "'occupancy_logs', "
            f"INTERVAL '{log_compression_after_days} days', "
            "if_not_exists => TRUE"
            ")"
        ),
        (
            "SELECT add_compression_policy("
            "'occupancy_area_snapshots', "
            f"INTERVAL '{snapshot_compression_after_days} days', "
            "if_not_exists => TRUE"
            ")"
        ),
    ]
    for statement in statements:
        _run_statement(statement)

    if not settings.occupancy_rollup_enabled:
        return

    rollup_statements = [
        (
            "CREATE MATERIALIZED VIEW IF NOT EXISTS occupancy_area_snapshots_1m "
            "WITH (timescaledb.continuous) AS "
            "SELECT "
            "time_bucket('1 minute', measured_at) AS bucket, "
            "location, "
            "area, "
            "AVG(occupancy_rate) AS avg_occupancy_rate, "
            "MAX(occupancy_rate) AS peak_occupancy_rate, "
            "SUM(sample_count) AS total_samples "
            "FROM occupancy_area_snapshots "
            "GROUP BY bucket, location, area "
            "WITH NO DATA"
        ),
        (
            "SELECT add_continuous_aggregate_policy("
            "'occupancy_area_snapshots_1m', "
            "start_offset => INTERVAL '7 days', "
            "end_offset => INTERVAL '1 minute', "
            "schedule_interval => INTERVAL '1 minute', "
            "if_not_exists => TRUE"
            ")"
        ),
    ]
    for statement in rollup_statements:
        _run_statement(statement)


def initialize_occupancy_storage() -> dict[str, object]:
    checked_at = datetime.now(timezone.utc).isoformat()
    _INIT_STATE.update(
        {
            "checked_at": checked_at,
            "base_schema_ready": False,
            "timescale_enabled": bool(settings.occupancy_timescale_enabled),
            "timescale_initialized": False,
            "error": None,
        }
    )

    if not _is_postgresql():
        logger.info("occupancy storage initialization skipped for non-postgresql database")
        _INIT_STATE["error"] = "database is not postgresql"
        return dict(_INIT_STATE)

    _ensure_base_occupancy_schema()
    _INIT_STATE["base_schema_ready"] = True

    if not settings.occupancy_timescale_enabled:
        return dict(_INIT_STATE)

    try:
        _configure_timescaledb()
        _INIT_STATE["timescale_initialized"] = True
    except Exception:
        _INIT_STATE["error"] = "timescaledb initialization failed"
        logger.exception("occupancy timescaledb initialization failed")
        if settings.occupancy_timescale_required:
            raise
    return dict(_INIT_STATE)


def get_occupancy_storage_status() -> dict[str, object]:
    status = dict(_INIT_STATE)
    status["engine"] = engine.dialect.name
    if engine.dialect.name != "postgresql":
        status["ok"] = False
        status["timescale_extension_installed"] = False
        status["timescale_log_hypertable"] = False
        status["timescale_snapshot_hypertable"] = False
        return status

    try:
        extension_installed = _run_scalar(
            "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'timescaledb')"
        )
        status["timescale_extension_installed"] = bool(extension_installed)
        if extension_installed:
            log_hypertable = _run_scalar(
                "SELECT EXISTS(SELECT 1 FROM timescaledb_information.hypertables WHERE hypertable_name = 'occupancy_logs')"
            )
            snapshot_hypertable = _run_scalar(
                "SELECT EXISTS(SELECT 1 FROM timescaledb_information.hypertables WHERE hypertable_name = 'occupancy_area_snapshots')"
            )
            status["timescale_log_hypertable"] = bool(log_hypertable)
            status["timescale_snapshot_hypertable"] = bool(snapshot_hypertable)
        else:
            status["timescale_log_hypertable"] = False
            status["timescale_snapshot_hypertable"] = False
        if status.get("timescale_enabled"):
            status["ok"] = bool(
                status["timescale_extension_installed"]
                and status["timescale_log_hypertable"]
                and status["timescale_snapshot_hypertable"]
            )
        else:
            status["ok"] = True
    except Exception as exc:
        status["ok"] = False
        status["timescale_extension_installed"] = False
        status["timescale_log_hypertable"] = False
        status["timescale_snapshot_hypertable"] = False
        status["runtime_error"] = str(exc)
    return status
