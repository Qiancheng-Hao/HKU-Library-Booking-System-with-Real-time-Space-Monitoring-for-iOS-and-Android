# HKU Library Booking System

Full-stack HKU library booking platform with four major parts:

- a Flutter mobile app for booking and occupancy viewing
- a FastAPI backend for authentication, reservations, AI orchestration, and occupancy APIs
- a standalone AI booking agent service for natural-language booking flows
- computer-vision tooling for seat and space occupancy detection

The repository also includes local infrastructure and streaming configs for PostgreSQL, Redis, RabbitMQ, and MediaMTX.

## What This Project Covers

- User registration and login
- Library and facility browsing
- Reservation creation, listing, and cancellation
- AI-assisted booking conversations
- Notification reminders for upcoming bookings
- Real-time occupancy lookup and recommendation APIs
- Camera / CV driven occupancy processing pipeline

## System Overview

```text
Flutter App
    |
    v
FastAPI Backend ------------------> PostgreSQL / TimescaleDB
    |                                     |
    |                                     v
    |-------------------------------> occupancy snapshots / reservations / users
    |
    |------> AI Agent Service
    |
    |------> Redis (cache / event windows)
    |
    |------> RabbitMQ (optional frame + stats pipeline)
    |
    |------> Computer Vision inference and camera capture jobs
    |
    |------> MediaMTX (optional RTSP / RTMP / WebRTC relay)
```

## Repository Layout

```text
.
├── frontend/         Flutter mobile app
├── backend/          FastAPI API, models, routers, services
├── ai_agent/         AI booking agent service
├── computer_vision/  CV models, scripts, experiments, and tests
├── docker-compose.yml
├── mediamtx.yml
├── env.example       shared infra env for local containers
└── README.md
```

## Main Tech Stack

- Frontend: Flutter, Provider
- Backend: FastAPI, SQLAlchemy, APScheduler
- Database: PostgreSQL / TimescaleDB
- Messaging / cache: RabbitMQ, Redis
- AI agent: Python service using an OpenAI-compatible LLM API
- Computer vision: OpenCV, PyTorch, Ultralytics

## Ports Used Locally

- Frontend -> backend:
  - Android emulator: `http://10.0.2.2:8000`
  - iOS simulator / web: `http://localhost:8000`
- Backend API: `http://127.0.0.1:8000`
- AI agent service: `http://127.0.0.1:8001`
- PostgreSQL container: `localhost:5433`
- Redis container: `localhost:6380`
- RabbitMQ:
  - AMQP: `localhost:5672`
  - management UI: `http://localhost:15672`
- MediaMTX:
  - RTSP: `localhost:8554`
  - RTMP: `localhost:1935`
  - WebRTC: `localhost:8889`

## Prerequisites

Minimum local setup:

- Flutter SDK
- Dart SDK
- Python 3.10+
- PostgreSQL

For the full occupancy pipeline:

- Redis
- RabbitMQ
- optional GPU / CUDA environment for CV workloads

## Quick Start

### Option 1: Minimal App Flow

Use this if you only want login, booking, reservations, notifications, and standard backend APIs.

1. Start PostgreSQL.
2. Run the backend.
3. Run the Flutter app.

The AI service and CV pipeline are optional for this path.

### Option 2: Full Local Stack

Use this if you also want AI-assisted booking and occupancy infrastructure.

1. Start infra containers with `docker compose`.
2. Run the backend.
3. Run the AI agent service.
4. Run the Flutter app.
5. Enable CV / camera capture only if you need occupancy ingestion.

## Infrastructure Setup

The root-level [env.example](./env.example) is used by [docker-compose.yml](./docker-compose.yml).

```bash
cp env.example .env
docker compose up -d
```

This brings up:

- PostgreSQL / TimescaleDB
- Redis
- RabbitMQ

Optional streaming support is configured in [mediamtx.yml](./mediamtx.yml). Start it separately only if your camera or streaming workflow needs it.

## Backend Setup

From the `backend/` directory:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp env.example .env
```

Then update `backend/.env`:

- `DATABASE_URL`
- `AI_AGENT_BASE_URL`
- `AI_AGENT_SHARED_SECRET` if you want backend <-> AI service auth
- Redis / RabbitMQ / occupancy flags if you are enabling the occupancy pipeline

Start the backend:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Useful endpoints:

- API base: `http://127.0.0.1:8000`
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`
- Health check: `http://127.0.0.1:8000/health`

### Seed Data

Seed library, facility type, alias, and facility data after the database is ready:

```bash
cd backend
psql postgresql://postgres:postgres@localhost:5432/hku_library -f seed_library_facility_data.sql
```

If you are using the Docker PostgreSQL service from this repo, adjust the port to `5433`.

### Backend Responsibilities

- JWT-based authentication
- libraries / facilities / timeslot APIs
- reservation creation and cancellation
- user reservation history
- AI session orchestration APIs
- occupancy snapshot and recommendation APIs
- optional background jobs for capture, inference, and aggregation

## Frontend Setup

From the `frontend/` directory:

```bash
cd frontend
flutter pub get
cp dart_defines.json.example dart_defines.json
```

Set `BASE_URL` in `dart_defines.json` when the backend is not on the default local address.

Example:

```json
{
  "BASE_URL": "http://192.168.x.x:8000"
}
```

Run the app:

```bash
flutter run --dart-define-from-file=dart_defines.json
```

### Frontend Structure

```text
frontend/lib/
├── app/           app bootstrapping, root shell, provider wiring
├── core/          shared auth, config, models, network, UI primitives
├── features/      feature-based data, controllers, screens, widgets
├── providers/     app-wide state
├── services/      notifications and platform integrations
└── theme/         theme and design tokens
```

Main features:

- `features/auth`
- `features/home`
- `features/library`
- `features/reservations`
- `features/settings`
- `features/ai_agent`

## AI Agent Setup

From the `ai_agent/` directory:

```bash
cd ai_agent
python -m venv .venv
source .venv/bin/activate
pip install -r ../backend/requirements.txt
cp env.example .env
```

Then configure:

- `AI_API_KEY`
- `AI_BASE_URL`
- `AI_MODEL`
- `AI_AGENT_SHARED_SECRET` to match `backend/.env`

Start the AI service:

```bash
python server.py
```

Expected default address: `http://127.0.0.1:8001`

### Important AI Agent Caveat

The AI agent uses hardcoded and semi-static library / facility mappings in `booking_system.py` and `facility_mapping.py`.

If your seeded local database IDs or room naming conventions differ from the expected defaults, the AI agent may fail to find rooms or create bookings. Check the module-specific notes in [ai_agent/README.md](./ai_agent/README.md) before debugging the conversation layer.

## Computer Vision Setup

The CV side is optional unless you are working on occupancy ingestion or model development.

Baseline Python packages are summarized in the root [requirements.txt](./requirements.txt), and the fuller workflow lives in [computer_vision/README.md](./computer_vision/README.md).

Typical local CV setup:

```bash
cd computer_vision
conda create -n hku-library python=3.10
conda activate hku-library
conda install -c conda-forge opencv
pip install ultralytics python-dotenv
pip install torch torchvision
```

If you need GPU acceleration, install the correct CUDA-compatible PyTorch build for your machine.

### CV Responsibilities

- seat detection
- person / item detection
- occupancy heuristics
- model training scripts
- test and visualization helpers

## Occupancy / Camera Pipeline

This repo supports more than one operating mode:

1. API only:
   - backend serves stored reservation and occupancy APIs
2. Snapshot aggregation:
   - backend aggregates occupancy snapshots from stored logs
3. Full capture + inference:
   - camera capture jobs ingest frames
   - optional RabbitMQ queue stages frames and stats
   - inference results are written back into the backend storage

Key toggles live in `backend/.env`:

- `OCCUPANCY_REALTIME_ENABLED`
- `OCCUPANCY_CACHE_ENABLED`
- `CAMERA_CAPTURE_ENABLED`
- `CAMERA_CAPTURE_USE_RABBITMQ`
- `OCCUPANCY_TIMESCALE_ENABLED`

## Recommended Local Bring-Up Order

For a clean local end-to-end workflow:

1. `cp env.example .env`
2. `docker compose up -d`
3. configure and run backend
4. seed the database
5. configure and run AI agent
6. configure and run Flutter app
7. enable CV / camera capture only when needed

## Testing

### Frontend

```bash
cd frontend
flutter analyze
flutter test
```

### Backend

There is not yet a single documented automated backend test command at the repo root. For now, validate backend changes through:

- local startup
- `/health`
- `/docs`
- target API smoke checks

### AI Agent / CV

These modules currently rely more on local execution and scenario validation than on a single standardized test entrypoint.

## Common Gotchas

- The backend `DATABASE_URL` in `backend/env.example` defaults to port `5432`, while the Docker PostgreSQL service in this repo exposes `5433`.
- The AI agent must be aligned with your real library IDs and facility naming conventions.
- Android emulators must hit the backend through `10.0.2.2`, not `localhost`.
- Notification reminders depend on device permission and local notification support.
- Occupancy and camera features require more infrastructure than the booking-only flow.

## Module Docs

- [backend/README.md](./backend/README.md)
- [ai_agent/README.md](./ai_agent/README.md)
- [computer_vision/README.md](./computer_vision/README.md)

## Status

The booking flow, app architecture, AI-assisted path, and occupancy infrastructure all live in the same repository, but they do not need to be started together for every development task. Treat the project as a platform with optional subsystems rather than a single mandatory runtime bundle.
