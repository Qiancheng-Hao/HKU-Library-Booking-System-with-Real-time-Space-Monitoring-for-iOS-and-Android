from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central application configuration."""

    model_config = SettingsConfigDict(
        env_file=("backend/.env", ".env", "backend/env.example"),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )
    
    # Application settings
    app_name: str = Field(default="HKU Library Booking API", alias="APP_NAME")
    api_version: str = Field(default="v1", alias="API_VERSION")
    debug: bool = Field(default=False, alias="API_DEBUG")
    log_to_file_enabled: bool = Field(default=True, alias="LOG_TO_FILE_ENABLED")
    log_file_path: str = Field(default="logs/backend.log", alias="LOG_FILE_PATH")
    log_file_max_bytes: int = Field(default=10485760, alias="LOG_FILE_MAX_BYTES")
    log_file_backup_count: int = Field(default=5, alias="LOG_FILE_BACKUP_COUNT")
    database_url: str = Field(
        default="postgresql+psycopg://postgres:postgres@localhost:5432/hku_library",
        alias="DATABASE_URL",
    )
    db_echo: bool = Field(default=False, alias="DB_ECHO")
    default_timezone: str = Field(default="Asia/Hong_Kong", alias="DEFAULT_TIMEZONE")
    
    # Reservation settings
    reservation_lead_days: int = Field(
        default=14,
        description="Maximum number of days ahead a user can make a reservation.",
    )
    reservation_slot_buffer_minutes: int = Field(
        default=5,
        description="Buffer minutes between reservation slots to avoid overlaps.",
    )
    
    # Log → occupancy_area_snapshots settings
    occupancy_realtime_enabled: bool = Field(
        default=True, alias="OCCUPANCY_REALTIME_ENABLED"
    )
    occupancy_realtime_refresh_seconds: int = Field(
        default=10, alias="OCCUPANCY_REALTIME_REFRESH_SECONDS"
    )
    occupancy_realtime_window_seconds: int = Field(
        default=10, alias="OCCUPANCY_REALTIME_WINDOW_SECONDS"
    )    
    # occupancy_refresh_minutes: Literal[5, 10, 15] = Field(
    #     default=5,
    #     description="Expected refresh cadence (minutes) for occupancy snapshots.",
    # )
    
    # Stream → log settings
    camera_capture_enabled: bool = Field(
        default=False, alias="CAMERA_CAPTURE_ENABLED"
    )
    camera_capture_interval_seconds: int = Field(
        default=3, alias="CAMERA_CAPTURE_INTERVAL_SECONDS"
    )
    camera_capture_use_rabbitmq: bool = Field(
        default=False, alias="CAMERA_CAPTURE_USE_RABBITMQ"
    )
    rabbitmq_url: str = Field(
        default="amqp://guest:guest@localhost:5672/%2F",
        alias="RABBITMQ_URL",
    )
    rabbitmq_frame_queue: str = Field(
        default="occupancy.frames",
        alias="RABBITMQ_FRAME_QUEUE",
    )
    rabbitmq_stats_queue: str = Field(
        default="occupancy.stats",
        alias="RABBITMQ_STATS_QUEUE",
    )
    rabbitmq_prefetch_count: int = Field(
        default=1, alias="RABBITMQ_PREFETCH_COUNT"
    )
    rabbitmq_frame_jpeg_quality: int = Field(
        default=80, alias="RABBITMQ_FRAME_JPEG_QUALITY"
    )
    rabbitmq_reconnect_seconds: float = Field(
        default=3.0, alias="RABBITMQ_RECONNECT_SECONDS"
    )
    redis_url: str = Field(
        default="redis://localhost:6379/0",
        alias="REDIS_URL",
    )
    occupancy_cache_enabled: bool = Field(
        default=True, alias="OCCUPANCY_CACHE_ENABLED"
    )
    occupancy_snapshot_cache_ttl_seconds: int = Field(
        default=60, alias="OCCUPANCY_SNAPSHOT_CACHE_TTL_SECONDS"
    )
    occupancy_window_retention_seconds: int = Field(
        default=120, alias="OCCUPANCY_WINDOW_RETENTION_SECONDS"
    )
    occupancy_event_dedupe_ttl_seconds: int = Field(
        default=86400, alias="OCCUPANCY_EVENT_DEDUPE_TTL_SECONDS"
    )
    occupancy_timescale_enabled: bool = Field(
        default=True, alias="OCCUPANCY_TIMESCALE_ENABLED"
    )
    occupancy_timescale_required: bool = Field(
        default=False, alias="OCCUPANCY_TIMESCALE_REQUIRED"
    )
    occupancy_log_chunk_interval: str = Field(
        default="1 day", alias="OCCUPANCY_LOG_CHUNK_INTERVAL"
    )
    occupancy_snapshot_chunk_interval: str = Field(
        default="7 days", alias="OCCUPANCY_SNAPSHOT_CHUNK_INTERVAL"
    )
    occupancy_log_retention_days: int = Field(
        default=14, alias="OCCUPANCY_LOG_RETENTION_DAYS"
    )
    occupancy_snapshot_retention_days: int = Field(
        default=180, alias="OCCUPANCY_SNAPSHOT_RETENTION_DAYS"
    )
    occupancy_log_compression_after_days: int = Field(
        default=2, alias="OCCUPANCY_LOG_COMPRESSION_AFTER_DAYS"
    )
    occupancy_snapshot_compression_after_days: int = Field(
        default=7, alias="OCCUPANCY_SNAPSHOT_COMPRESSION_AFTER_DAYS"
    )
    occupancy_rollup_enabled: bool = Field(
        default=True, alias="OCCUPANCY_ROLLUP_ENABLED"
    )
    occupancy_reports_aggregates_enabled: bool = Field(
        default=True, alias="OCCUPANCY_REPORTS_AGGREGATES_ENABLED"
    )
    occupancy_reports_30m_view_name: str = Field(
        default="occupancy_reports_30m",
        alias="OCCUPANCY_REPORTS_30M_VIEW_NAME",
    )
    occupancy_reports_30m_bucket_interval: str = Field(
        default="30 minutes",
        alias="OCCUPANCY_REPORTS_30M_BUCKET_INTERVAL",
    )
    occupancy_reports_30m_start_offset: str = Field(
        default="30 days",
        alias="OCCUPANCY_REPORTS_30M_START_OFFSET",
    )
    occupancy_reports_30m_end_offset: str = Field(
        default="30 minutes",
        alias="OCCUPANCY_REPORTS_30M_END_OFFSET",
    )
    occupancy_reports_30m_schedule_interval: str = Field(
        default="15 minutes",
        alias="OCCUPANCY_REPORTS_30M_SCHEDULE_INTERVAL",
    )
    occupancy_reports_1h_view_name: str = Field(
        default="occupancy_reports_1h",
        alias="OCCUPANCY_REPORTS_1H_VIEW_NAME",
    )
    occupancy_reports_1h_bucket_interval: str = Field(
        default="1 hour",
        alias="OCCUPANCY_REPORTS_1H_BUCKET_INTERVAL",
    )
    occupancy_reports_1h_start_offset: str = Field(
        default="180 days",
        alias="OCCUPANCY_REPORTS_1H_START_OFFSET",
    )
    occupancy_reports_1h_end_offset: str = Field(
        default="1 hour",
        alias="OCCUPANCY_REPORTS_1H_END_OFFSET",
    )
    occupancy_reports_1h_schedule_interval: str = Field(
        default="1 hour",
        alias="OCCUPANCY_REPORTS_1H_SCHEDULE_INTERVAL",
    )
    
    # Authentication settings
    secret_key: str = Field(
        default="09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7",
        alias="SECRET_KEY",
    )
    algorithm: str = Field(default="HS256", alias="ALGORITHM")
    access_token_expire_minutes: int = Field(
        default=30, alias="ACCESS_TOKEN_EXPIRE_MINUTES"
    )
    ai_agent_enabled: bool = Field(default=True, alias="AI_AGENT_ENABLED")
    ai_agent_base_url: str = Field(
        default="http://127.0.0.1:8001", alias="AI_AGENT_BASE_URL"
    )
    ai_agent_timeout_seconds: float = Field(
        default=10.0, alias="AI_AGENT_TIMEOUT_SECONDS"
    )
    ai_agent_shared_secret: str = Field(default="", alias="AI_AGENT_SHARED_SECRET")
    ai_session_timeout_minutes: int = Field(
        default=30, alias="AI_SESSION_TIMEOUT_MINUTES"
    )
    
    # Computer Vision settings
    cv_device: str = Field(default="auto", alias="CV_DEVICE")
    cv_debug_enabled: bool = Field(default=False, alias="CV_DEBUG_ENABLED")
    cv_confidence_threshold: float = Field(default=0.5, alias="CV_CONFIDENCE_THRESHOLD")
    cv_proximity_threshold: float = Field(default=100.0, alias="CV_PROXIMITY_THRESHOLD")
    cv_item_cluster_threshold: float = Field(
        default=150.0, alias="CV_ITEM_CLUSTER_THRESHOLD"
    )
    cv_seat_expansion_factor: float = Field(
        default=1.5, alias="CV_SEAT_EXPANSION_FACTOR"
    )
    cv_imgsz: int = Field(default=640, alias="CV_IMAGE_SIZE")
    cv_seat_imgsz: int = Field(default=640, alias="CV_SEAT_IMAGE_SIZE")
    cv_occupancy_model_path: str | None = Field(
        default=None,
        alias="CV_OCCUPANCY_MODEL_PATH",
    )
    cv_seat_model_path: str | None = Field(
        default=None,
        alias="CV_SEAT_MODEL_PATH",
    )


@lru_cache
def get_settings() -> Settings:
    """Return a cached settings instance."""

    return Settings()


settings = get_settings()

