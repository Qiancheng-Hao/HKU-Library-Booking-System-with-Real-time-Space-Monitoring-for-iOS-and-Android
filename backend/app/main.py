import asyncio
import logging
from datetime import datetime, timezone
from logging.handlers import RotatingFileHandler
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from jose import JWTError
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
from apscheduler.schedulers.background import BackgroundScheduler
from app.core.tasks import update_expired_reservations

from app import models  # noqa: F401
from app.models.occupancy import OccupancyLog  # Ensure model is imported for create_all
from app.core.config import settings
from app.core.database import Base, engine
from app.core import security
from app.routers import ai, auth, facilities, libraries, occupancy_cv, reservations
from app.services.occupancy_cv_service import (
    compute_and_store_area_snapshots,
    run_camera_capture_cycle,
)
from app.services.occupancy_rabbitmq_service import RabbitMQCameraPipeline
from app.services.occupancy_cache_service import get_redis_client
from app.services.occupancy_storage_service import (
    get_occupancy_storage_status,
    initialize_occupancy_storage,
)


def _configure_logging() -> None:
    root_level = logging.DEBUG if settings.debug else logging.INFO
    formatter = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
    )
    logging.basicConfig(level=root_level, format=formatter._fmt)
    root_logger = logging.getLogger()
    root_logger.setLevel(root_level)

    if settings.log_to_file_enabled:
        log_path = Path(settings.log_file_path)
        if not log_path.is_absolute():
            log_path = Path.cwd() / log_path
        log_path.parent.mkdir(parents=True, exist_ok=True)
        file_handler = RotatingFileHandler(
            filename=str(log_path),
            maxBytes=max(1024, int(settings.log_file_max_bytes)),
            backupCount=max(1, int(settings.log_file_backup_count)),
            encoding="utf-8",
        )
        file_handler.setLevel(root_level)
        file_handler.setFormatter(formatter)
        root_logger.addHandler(file_handler)
        for logger_name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
            named_logger = logging.getLogger(logger_name)
            named_logger.setLevel(root_level)
            named_logger.addHandler(file_handler)

    if not settings.debug:
        logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
        logging.getLogger("apscheduler").setLevel(logging.WARNING)


_configure_logging()
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.app_name,
    version=settings.api_version,
    debug=settings.debug,
)

logger = logging.getLogger(__name__)


def _rabbitmq_health_status() -> dict[str, object]:
    status: dict[str, object] = {
        "enabled": bool(settings.camera_capture_use_rabbitmq),
        "queue_frame": settings.rabbitmq_frame_queue,
        "queue_stats": settings.rabbitmq_stats_queue,
        "ok": False,
    }
    try:
        import pika
    except Exception as exc:
        status["error"] = f"pika unavailable: {exc}"
        return status

    try:
        params = pika.URLParameters(settings.rabbitmq_url)
        params.socket_timeout = 2
        params.connection_attempts = 1
        params.retry_delay = 0
        connection = pika.BlockingConnection(params)
        channel = connection.channel()
        channel.queue_declare(queue=settings.rabbitmq_frame_queue, durable=True)
        channel.queue_declare(queue=settings.rabbitmq_stats_queue, durable=True)
        connection.close()
        status["ok"] = True
        return status
    except Exception as exc:
        status["error"] = str(exc)
        return status


def _redis_health_status() -> dict[str, object]:
    status: dict[str, object] = {
        "enabled": bool(settings.occupancy_cache_enabled),
        "ok": False,
        "url": settings.redis_url,
    }
    try:
        client = get_redis_client()
        pong = client.ping()
        status["ok"] = bool(pong)
    except Exception as exc:
        status["error"] = str(exc)
    return status

class TokenAuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        if request.method == "OPTIONS":
            return await call_next(request)
        if (
            path == f"/api/{settings.api_version}/auth/login"
            or path == f"/api/{settings.api_version}/auth/register"
            or path == "/health"
            or path in ("/docs", "/redoc", "/openapi.json")
        ):
            return await call_next(request)
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return JSONResponse(
                status_code=401,
                content={"detail": "Not authenticated"},
                headers={"WWW-Authenticate": "Bearer"},
            )
        token = auth_header.split(" ", 1)[1]
        try:
            subject = security.decode_access_token(token)
            request.state.user_subject = subject
        except JWTError:
            return JSONResponse(
                status_code=401,
                content={"detail": "Invalid or expired token"},
                headers={"WWW-Authenticate": "Bearer"},
            )
        return await call_next(request)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(TokenAuthMiddleware)

app.include_router(auth.router, prefix=f"/api/{settings.api_version}")
app.include_router(ai.router, prefix=f"/api/{settings.api_version}")
app.include_router(libraries.router, prefix=f"/api/{settings.api_version}")
app.include_router(facilities.router, prefix=f"/api/{settings.api_version}")
app.include_router(reservations.router, prefix=f"/api/{settings.api_version}")
app.include_router(occupancy_cv.router, prefix=f"/api/{settings.api_version}")

# log to area snapshots
async def _run_occupancy_realtime_loop() -> None:
    refresh_seconds = max(1, int(settings.occupancy_realtime_refresh_seconds))
    window_seconds = max(1, int(settings.occupancy_realtime_window_seconds))
    while True:
        try:
            compute_and_store_area_snapshots(window_seconds=window_seconds)
        except Exception:
            logger.exception("occupancy realtime loop failed")
        await asyncio.sleep(refresh_seconds)

# camera to log
async def _run_camera_capture_loop() -> None:
    interval_seconds = max(1, int(settings.camera_capture_interval_seconds))
    while True:
        try:
            captured = await asyncio.to_thread(run_camera_capture_cycle)
            logger.info("camera capture cycle finished: captured=%s", captured)
        except Exception:
            logger.exception("camera capture loop failed")
        await asyncio.sleep(interval_seconds)


@app.on_event("startup")
async def start_background_tasks() -> None:
    app.state.occupancy_storage_init = initialize_occupancy_storage()

    scheduler = BackgroundScheduler()
    scheduler.add_job(update_expired_reservations, 'cron', minute='0,15,30,45')
    scheduler.start()
    app.state.scheduler = scheduler

    if settings.occupancy_realtime_enabled:
        app.state.occupancy_realtime_task = asyncio.create_task(_run_occupancy_realtime_loop())
    if settings.camera_capture_enabled:
        if settings.camera_capture_use_rabbitmq:
            pipeline = RabbitMQCameraPipeline()
            pipeline.start()
            app.state.rabbitmq_camera_pipeline = pipeline
        else:
            app.state.camera_capture_task = asyncio.create_task(_run_camera_capture_loop())


@app.on_event("shutdown")
async def stop_background_tasks() -> None:
    scheduler = getattr(app.state, "scheduler", None)
    if scheduler:
        scheduler.shutdown()

    task = getattr(app.state, "occupancy_realtime_task", None)
    if task is not None:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
    task = getattr(app.state, "camera_capture_task", None)
    if task is not None:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
    pipeline = getattr(app.state, "rabbitmq_camera_pipeline", None)
    if pipeline is not None:
        await asyncio.to_thread(pipeline.stop)


@app.get("/health", tags=["Health"])
def health_check():
    checks = {
        "rabbitmq": _rabbitmq_health_status(),
        "redis": _redis_health_status(),
        "timescaledb": get_occupancy_storage_status(),
    }
    all_ok = all(bool(item.get("ok", True)) for item in checks.values())
    return {
        "status": "ok" if all_ok else "degraded",
        "app": settings.app_name,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "checks": checks,
    }
