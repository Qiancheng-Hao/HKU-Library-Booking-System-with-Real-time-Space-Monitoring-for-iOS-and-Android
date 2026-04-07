import asyncio
import logging

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


def _configure_logging() -> None:
    root_level = logging.DEBUG if settings.debug else logging.INFO
    logging.basicConfig(level=root_level)
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
    return {"status": "ok", "app": settings.app_name}
