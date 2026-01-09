from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central application configuration."""

    model_config = SettingsConfigDict(
        env_file=("backend/.env", ".env", "backend/env.example"),
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    app_name: str = Field(default="HKU Library Booking API", alias="APP_NAME")
    api_version: str = Field(default="v1", alias="API_VERSION")
    debug: bool = Field(default=False, alias="API_DEBUG")
    database_url: str = Field(
        default="postgresql+psycopg://postgres:postgres@localhost:5432/hku_library",
        alias="DATABASE_URL",
    )
    default_timezone: str = Field(default="Asia/Hong_Kong", alias="DEFAULT_TIMEZONE")
    reservation_lead_days: int = Field(
        default=14,
        description="Maximum number of days ahead a user can make a reservation.",
    )
    reservation_slot_buffer_minutes: int = Field(
        default=5,
        description="Buffer minutes between reservation slots to avoid overlaps.",
    )
    occupancy_refresh_minutes: Literal[5, 10, 15] = Field(
        default=5,
        description="Expected refresh cadence (minutes) for occupancy snapshots.",
    )
    occupancy_realtime_enabled: bool = Field(
        default=True, alias="OCCUPANCY_REALTIME_ENABLED"
    )
    occupancy_realtime_refresh_seconds: int = Field(
        default=10, alias="OCCUPANCY_REALTIME_REFRESH_SECONDS"
    )
    occupancy_realtime_window_seconds: int = Field(
        default=10, alias="OCCUPANCY_REALTIME_WINDOW_SECONDS"
    )
    camera_capture_enabled: bool = Field(
        default=False, alias="CAMERA_CAPTURE_ENABLED"
    )
    camera_capture_interval_seconds: int = Field(
        default=3, alias="CAMERA_CAPTURE_INTERVAL_SECONDS"
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
    # cv_model_paths are determined by service
    # cv_occupancy_model_path: str | None = Field(
    #     default=None,
    #     alias="CV_OCCUPANCY_MODEL_PATH",
    # )
    # cv_seat_model_path: str | None = Field(
    #     default=None,
    #     alias="CV_SEAT_MODEL_PATH",
    # )
    cv_device: str = Field(default="auto", alias="CV_DEVICE")
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



@lru_cache
def get_settings() -> Settings:
    """Return a cached settings instance."""

    return Settings()


settings = get_settings()

