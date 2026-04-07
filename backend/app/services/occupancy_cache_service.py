from __future__ import annotations

import json
import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache

from app.core.config import settings

logger = logging.getLogger(__name__)

_AREA_SEPARATOR = "\x1f"
_ACTIVE_AREAS_KEY = "occupancy:areas:active"


@dataclass(frozen=True)
class OccupancyStatsEvent:
    event_id: uuid.UUID
    location: str
    area: str
    captured_at: datetime
    occupancy_rate: float
    total_people: int
    total_hogging: int
    total_seats: int
    camera_name: str | None = None


@dataclass(frozen=True)
class CachedAreaSnapshot:
    location: str
    area: str
    occupancy_rate: float
    sample_count: int
    window_seconds: int
    measured_at: datetime


def _ensure_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _event_payload(event: OccupancyStatsEvent) -> str:
    return json.dumps(
        {
            "event_id": str(event.event_id),
            "location": event.location,
            "area": event.area,
            "captured_at": _ensure_utc(event.captured_at).isoformat(),
            "occupancy_rate": float(event.occupancy_rate),
            "total_people": int(event.total_people),
            "total_hogging": int(event.total_hogging),
            "total_seats": int(event.total_seats),
            "camera_name": event.camera_name,
        },
        separators=(",", ":"),
        sort_keys=True,
    )


def _snapshot_payload(snapshot: CachedAreaSnapshot) -> str:
    return json.dumps(
        {
            "location": snapshot.location,
            "area": snapshot.area,
            "occupancy_rate": float(snapshot.occupancy_rate),
            "sample_count": int(snapshot.sample_count),
            "window_seconds": int(snapshot.window_seconds),
            "measured_at": _ensure_utc(snapshot.measured_at).isoformat(),
        },
        separators=(",", ":"),
        sort_keys=True,
    )


def _window_key(location: str, area: str) -> str:
    return f"occupancy:window:{location}:{area}"


def _snapshot_key(location: str, area: str) -> str:
    return f"occupancy:snapshot:latest:{location}:{area}"


def _dedupe_key(event_id: uuid.UUID) -> str:
    return f"occupancy:event:{event_id}"


def _area_member(location: str, area: str) -> str:
    return f"{location}{_AREA_SEPARATOR}{area}"


def _parse_area_member(value: str) -> tuple[str, str] | None:
    location, separator, area = value.partition(_AREA_SEPARATOR)
    if not separator or not location or not area:
        return None
    return location, area


def _decode_event(value: str) -> OccupancyStatsEvent | None:
    try:
        payload = json.loads(value)
        return OccupancyStatsEvent(
            event_id=uuid.UUID(str(payload["event_id"])),
            location=str(payload["location"]),
            area=str(payload["area"]),
            captured_at=_ensure_utc(datetime.fromisoformat(str(payload["captured_at"]))),
            occupancy_rate=float(payload["occupancy_rate"]),
            total_people=int(payload["total_people"]),
            total_hogging=int(payload["total_hogging"]),
            total_seats=int(payload["total_seats"]),
            camera_name=str(payload["camera_name"]) if payload.get("camera_name") else None,
        )
    except Exception:
        logger.exception("failed to decode cached occupancy event")
        return None


def _decode_snapshot(value: str) -> CachedAreaSnapshot | None:
    try:
        payload = json.loads(value)
        return CachedAreaSnapshot(
            location=str(payload["location"]),
            area=str(payload["area"]),
            occupancy_rate=float(payload["occupancy_rate"]),
            sample_count=int(payload["sample_count"]),
            window_seconds=int(payload["window_seconds"]),
            measured_at=_ensure_utc(datetime.fromisoformat(str(payload["measured_at"]))),
        )
    except Exception:
        logger.exception("failed to decode cached occupancy snapshot")
        return None


def cache_enabled() -> bool:
    return bool(settings.occupancy_cache_enabled)


@lru_cache(maxsize=1)
def get_redis_client():
    import redis

    return redis.Redis.from_url(settings.redis_url, decode_responses=True)


def add_stats_event_to_window(event: OccupancyStatsEvent) -> bool:
    if not cache_enabled():
        return True

    client = get_redis_client()
    timestamp = _ensure_utc(event.captured_at).timestamp()
    retention_seconds = max(
        int(settings.occupancy_window_retention_seconds),
        int(settings.occupancy_realtime_window_seconds) * 2,
    )
    event_payload = _event_payload(event)
    dedupe_ttl = max(1, int(settings.occupancy_event_dedupe_ttl_seconds))
    window_key = _window_key(event.location, event.area)

    try:
        if not client.set(_dedupe_key(event.event_id), "1", nx=True, ex=dedupe_ttl):
            return False

        pipeline = client.pipeline(transaction=False)
        pipeline.zadd(window_key, {event_payload: timestamp})
        pipeline.zremrangebyscore(window_key, "-inf", timestamp - retention_seconds)
        pipeline.expire(window_key, retention_seconds)
        pipeline.sadd(_ACTIVE_AREAS_KEY, _area_member(event.location, event.area))
        pipeline.execute()
        return True
    except Exception:
        logger.exception("failed to write occupancy event to redis")
        return True


def get_active_areas() -> list[tuple[str, str]]:
    if not cache_enabled():
        return []

    try:
        members = get_redis_client().smembers(_ACTIVE_AREAS_KEY)
    except Exception:
        logger.exception("failed to load active occupancy areas from redis")
        return []

    result: list[tuple[str, str]] = []
    for member in members:
        parsed = _parse_area_member(member)
        if parsed is not None:
            result.append(parsed)
    result.sort()
    return result


def get_window_events(
    *,
    location: str,
    area: str,
    window_seconds: int,
    measured_at: datetime,
) -> list[OccupancyStatsEvent]:
    if not cache_enabled():
        return []

    measured_at = _ensure_utc(measured_at)
    min_score = measured_at.timestamp() - max(1, int(window_seconds))
    max_score = measured_at.timestamp()

    try:
        values = get_redis_client().zrangebyscore(
            _window_key(location, area),
            min=min_score,
            max=max_score,
        )
    except Exception:
        logger.exception("failed to read occupancy window from redis")
        return []

    events: list[OccupancyStatsEvent] = []
    for value in values:
        decoded = _decode_event(value)
        if decoded is not None and decoded.occupancy_rate >= 0:
            events.append(decoded)
    return events


def store_latest_snapshot(snapshot: CachedAreaSnapshot) -> None:
    if not cache_enabled():
        return

    ttl_seconds = max(1, int(settings.occupancy_snapshot_cache_ttl_seconds))
    try:
        pipeline = get_redis_client().pipeline(transaction=False)
        pipeline.set(
            _snapshot_key(snapshot.location, snapshot.area),
            _snapshot_payload(snapshot),
            ex=ttl_seconds,
        )
        pipeline.sadd(_ACTIVE_AREAS_KEY, _area_member(snapshot.location, snapshot.area))
        pipeline.execute()
    except Exception:
        logger.exception("failed to store latest occupancy snapshot in redis")


def get_latest_snapshot(location: str, area: str) -> CachedAreaSnapshot | None:
    if not cache_enabled():
        return None

    try:
        value = get_redis_client().get(_snapshot_key(location, area))
    except Exception:
        logger.exception("failed to read latest occupancy snapshot from redis")
        return None

    if not value:
        return None
    return _decode_snapshot(value)


def get_all_latest_snapshots() -> list[CachedAreaSnapshot]:
    if not cache_enabled():
        return []

    areas = get_active_areas()
    if not areas:
        return []

    client = get_redis_client()
    pipeline = client.pipeline(transaction=False)
    for location, area in areas:
        pipeline.get(_snapshot_key(location, area))

    try:
        values = pipeline.execute()
    except Exception:
        logger.exception("failed to read latest occupancy snapshot batch from redis")
        return []

    snapshots: list[CachedAreaSnapshot] = []
    for value in values:
        if not value:
            continue
        decoded = _decode_snapshot(value)
        if decoded is not None:
            snapshots.append(decoded)
    return snapshots
