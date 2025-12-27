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
    secret_key: str = Field(
        default="09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7",
        alias="SECRET_KEY",
    )
    algorithm: str = Field(default="HS256", alias="ALGORITHM")
    access_token_expire_minutes: int = Field(
        default=30, alias="ACCESS_TOKEN_EXPIRE_MINUTES"
    )



@lru_cache
def get_settings() -> Settings:
    """Return a cached settings instance."""

    return Settings()


settings = get_settings()

