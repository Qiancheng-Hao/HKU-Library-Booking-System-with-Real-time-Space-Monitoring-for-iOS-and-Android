# Backend

## Overview

This backend is a FastAPI service for the HKU Library Booking System. It provides:

- user registration, login, and JWT-based authentication
- library and facility browsing
- reservation creation, cancellation, and personal reservation lookup
- AI-assisted booking session orchestration
- real-time occupancy lookup and recommendation APIs
- optional background jobs for camera capture and occupancy aggregation

The application entrypoint is [main.py](file:///e:/work/COMP4801/HKU-Library-Booking-System-with-Real-time-Space-Monitoring-for-iOS-and-Android-1/backend/app/main.py).

## Tech Stack

- FastAPI
- SQLAlchemy
- PostgreSQL via `psycopg`
- JWT authentication with `python-jose`
- APScheduler for periodic background jobs
- OpenCV, PyTorch, and Ultralytics for occupancy-related CV features

## Quick Start

From the `backend` directory:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy env.example .env
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

After startup:

- API base URL: `http://127.0.0.1:8000`
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`
- Health check: `http://127.0.0.1:8000/health`

## Database Setup

- The backend uses `DATABASE_URL` to connect to PostgreSQL.
- On startup, `Base.metadata.create_all(...)` creates tables defined by the current SQLAlchemy models.
- Seed data for libraries, facility types, aliases, and facilities is provided in [seed_library_facility_data.sql](file:///e:/work/COMP4801/HKU-Library-Booking-System-with-Real-time-Space-Monitoring-for-iOS-and-Android-1/backend/seed_library_facility_data.sql).

Typical local flow:

```bash
psql postgresql://postgres:postgres@localhost:5432/hku_library -f seed_library_facility_data.sql
```

## Authentication

- All `/api/<version>/...` routes require `Authorization: Bearer <token>` by default.
- The following routes are public:
  - `/api/<version>/auth/register`
  - `/api/<version>/auth/login`
  - `/health`
  - `/docs`
  - `/redoc`
  - `/openapi.json`

## API Summary

Current router groups:

- Authentication
  - `POST /api/<version>/auth/register`
  - `POST /api/<version>/auth/login`
  - `GET /api/<version>/auth/me`
- Libraries
  - `GET /api/<version>/libraries`
  - `GET /api/<version>/libraries/{library_id}`
- Facilities
  - `GET /api/<version>/facilities/{facility_id}/timeslots`
- Reservations
  - `POST /api/<version>/reservations`
  - `DELETE /api/<version>/reservations/{reservation_id}`
  - `GET /api/<version>/reservations/my`
- AI booking
  - `POST /api/<version>/ai/session`
  - `GET /api/<version>/ai/session/{ai_session_id}`
  - `DELETE /api/<version>/ai/session/{ai_session_id}`
  - `POST /api/<version>/ai/chat`
  - `POST /api/<version>/ai/confirm`
  - `POST /api/<version>/ai/reset`
- Occupancy
  - `POST /api/<version>/occupancy/occupancy`
  - `POST /api/<version>/occupancy/recommendation`

For exact request and response schemas, use the OpenAPI docs at `/docs`.

## Startup Behavior

When the service starts, it can launch several background tasks in addition to the HTTP API:

- reservation cleanup job
  - runs every hour at minute `0, 15, 30, 45`
  - calls `update_expired_reservations`
- occupancy aggregation loop
  - optional
  - reads from `occupancy_logs`
  - writes area-level snapshots into `occupancy_area_snapshots`
- camera capture loop
  - optional
  - reads enabled camera sources from `camera_sources`
  - captures frames, runs CV inference, and stores results into `occupancy_logs`

## Configuration Loading

Backend configuration is loaded by `Settings` in [config.py](file:///e:/work/COMP4801/HKU-Library-Booking-System-with-Real-time-Space-Monitoring-for-iOS-and-Android-1/backend/app/core/config.py) with the following priority from high to low:

1. `backend/.env`
2. project root `.env`
3. `backend/env.example`

Environment variable names are case-insensitive.

## Environment Variables

### Application

- `APP_NAME` default `HKU Library Booking API`
- `API_VERSION` default `v1`
- `API_DEBUG` default `false`
- `DATABASE_URL` default `postgresql+psycopg://postgres:postgres@localhost:5432/hku_library`
- `DB_ECHO` default `false`
- `DEFAULT_TIMEZONE` default `Asia/Hong_Kong`

### Reservations

- `RESERVATION_LEAD_DAYS` default `14`
- `RESERVATION_SLOT_BUFFER_MINUTES` default `5`

### Authentication

- `SECRET_KEY` default project built-in value
- `ALGORITHM` default `HS256`
- `ACCESS_TOKEN_EXPIRE_MINUTES` default `30`

### AI Agent Integration

- `AI_AGENT_ENABLED` default `true`
- `AI_AGENT_BASE_URL` default `http://127.0.0.1:8001`
- `AI_AGENT_TIMEOUT_SECONDS` default `10`
- `AI_AGENT_SHARED_SECRET` default empty string
- `AI_SESSION_TIMEOUT_MINUTES` default `30`

### Occupancy Aggregation

- `OCCUPANCY_REALTIME_ENABLED` default `true`
- `OCCUPANCY_REALTIME_REFRESH_SECONDS` default `10`
- `OCCUPANCY_REALTIME_WINDOW_SECONDS` default `10`

### Camera Capture

- `CAMERA_CAPTURE_ENABLED` default `false`
- `CAMERA_CAPTURE_INTERVAL_SECONDS` default `3`

Notes:

- each capture writes one row into `occupancy_logs`
- `video_source` is set to the corresponding camera `name`
- each camera should provide `name`, `stream_url`, `location`, `area`, and `enabled`

### Computer Vision

- `CV_DEVICE` default `auto`
- `CV_DEBUG_ENABLED` default `false`
- `CV_CONFIDENCE_THRESHOLD` default `0.5`
- `CV_PROXIMITY_THRESHOLD` default `100.0`
- `CV_ITEM_CLUSTER_THRESHOLD` default `150.0`
- `CV_SEAT_EXPANSION_FACTOR` default `1.5`
- `CV_IMAGE_SIZE` default `640`
- `CV_SEAT_IMAGE_SIZE` default `640`
- `CV_OCCUPANCY_MODEL_PATH` optional custom occupancy model path
- `CV_SEAT_MODEL_PATH` optional custom seat model path

If `CV_OCCUPANCY_MODEL_PATH` or `CV_SEAT_MODEL_PATH` is not set, the backend falls back to the repository defaults under `computer_vision/...`.

## Example `.env`

Create `backend/.env`:

```env
APP_NAME=HKU Library Booking API
API_VERSION=v1
API_DEBUG=true
DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/hku_library
DB_ECHO=false
DEFAULT_TIMEZONE=Asia/Hong_Kong

RESERVATION_LEAD_DAYS=14
RESERVATION_SLOT_BUFFER_MINUTES=5

SECRET_KEY=change-me
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

AI_AGENT_ENABLED=true
AI_AGENT_BASE_URL=http://127.0.0.1:8001
AI_AGENT_TIMEOUT_SECONDS=10
AI_AGENT_SHARED_SECRET=
AI_SESSION_TIMEOUT_MINUTES=30

OCCUPANCY_REALTIME_ENABLED=true
OCCUPANCY_REALTIME_REFRESH_SECONDS=10
OCCUPANCY_REALTIME_WINDOW_SECONDS=10

CAMERA_CAPTURE_ENABLED=false
CAMERA_CAPTURE_INTERVAL_SECONDS=3

CV_DEVICE=auto
CV_DEBUG_ENABLED=false
CV_CONFIDENCE_THRESHOLD=0.5
CV_PROXIMITY_THRESHOLD=100.0
CV_ITEM_CLUSTER_THRESHOLD=150.0
CV_SEAT_EXPANSION_FACTOR=1.5
CV_IMAGE_SIZE=640
CV_SEAT_IMAGE_SIZE=640
CV_OCCUPANCY_MODEL_PATH=../computer_vision/model/mixed/model_v3/best.pt
CV_SEAT_MODEL_PATH=../computer_vision/model/mixed/model_v3/best.pt
```

## Notes

- CORS is currently configured to allow all origins.
- The backend automatically exposes OpenAPI docs through FastAPI.
- AI endpoints depend on the upstream AI agent being reachable at `AI_AGENT_BASE_URL`.
- Occupancy endpoints can run without camera capture enabled, but they are only useful when occupancy snapshot data already exists.
