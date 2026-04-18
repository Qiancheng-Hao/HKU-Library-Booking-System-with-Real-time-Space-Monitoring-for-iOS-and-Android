# Backend

This backend is a FastAPI service for authentication, library browsing, reservations, AI booking orchestration, occupancy snapshots, and occupancy reports.

## Entry Point

- app: [`app/main.py`](./app/main.py)
- config: [`app/core/config.py`](./app/core/config.py)
- environment template: [`env.example`](./env.example)
- seed data: [`seed_library_facility_data.sql`](./seed_library_facility_data.sql)

## Quick Start

From the `backend/` directory:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp env.example .env
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

After startup:

- API base: `http://127.0.0.1:8000/api/v1`
- docs: `http://127.0.0.1:8000/docs`
- redoc: `http://127.0.0.1:8000/redoc`
- health: `http://127.0.0.1:8000/health`

## Minimum Local Setup

The backend only needs PostgreSQL to boot. For a lighter local setup, disable the optional occupancy services in `backend/.env`:

```env
OCCUPANCY_TIMESCALE_ENABLED=false
OCCUPANCY_CACHE_ENABLED=false
CAMERA_CAPTURE_ENABLED=false
CAMERA_CAPTURE_USE_RABBITMQ=false
```

## Database Setup

`DATABASE_URL` defaults to:

```env
postgresql+psycopg://postgres:postgres@localhost:5432/hku_library
```

On startup, the app creates tables for the current SQLAlchemy models. Seed the library and facility data once your database is ready:

From `backend/`:

```bash
psql postgresql://postgres:postgres@localhost:5432/hku_library -f seed_library_facility_data.sql
```

From the repository root:

```bash
psql postgresql://postgres:postgres@localhost:5432/hku_library -f backend/seed_library_facility_data.sql
```

## Authentication

All `/api/v1/...` routes require `Authorization: Bearer <token>` except:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /health`
- `GET /docs`
- `GET /redoc`
- `GET /openapi.json`

## Route Groups

Use `/docs` for exact schemas. The main router groups are:

- `/api/v1/auth`
- `/api/v1/libraries`
- `/api/v1/facilities`
- `/api/v1/reservations`
- `/api/v1/ai`
- `/api/v1/occupancy`
- `/api/v1/reports`

## AI Agent Integration

The backend talks to the separate AI agent service through:

- `AI_AGENT_BASE_URL`
- `AI_AGENT_TIMEOUT_SECONDS`
- `AI_AGENT_SHARED_SECRET`

By default the backend expects the AI agent at `http://127.0.0.1:8001`.

## Startup Behavior

Besides the HTTP API, startup may also:

- initialize occupancy storage and optional TimescaleDB helpers
- start the reservation cleanup scheduler
- start the occupancy snapshot loop
- start camera capture directly or through RabbitMQ

Those behaviors are controlled by environment variables in [`env.example`](./env.example).

## Configuration Notes

Settings are loaded in this order:

1. `backend/.env`
2. project root `.env`
3. `backend/env.example`

Important variables to check first:

- `DATABASE_URL`
- `API_DEBUG`
- `SECRET_KEY`
- `AI_AGENT_BASE_URL`
- `REDIS_URL`
- `RABBITMQ_URL`
- `CV_OCCUPANCY_MODEL_PATH`
- `CV_SEAT_MODEL_PATH`

For the full list, use [`env.example`](./env.example) as the source of truth.
