# Backend

## Configuration Loading

Backend configuration is loaded by `Settings` in [config.py](file:///e:/work/COMP4801/HKU-Library-Booking-System-with-Real-time-Space-Monitoring-for-iOS-and-Android-1/backend/app/core/config.py), with the following priority (highest → lowest):

1. `backend/.env`
2. project root `.env`
3. `backend/env.example`

Environment variable names are case-insensitive (`case_sensitive=False`).

## Configuration Parameters (Environment Variables)

### Application

- `APP_NAME` (default: `HKU Library Booking API`): service name
- `API_VERSION` (default: `v1`): API version prefix used as `/api/<API_VERSION>/...`
- `API_DEBUG` (default: `false`): debug mode
- `DATABASE_URL` (default: `postgresql+psycopg://postgres:postgres@localhost:5432/hku_library`): database connection string
- `DEFAULT_TIMEZONE` (default: `Asia/Hong_Kong`): default timezone (used by time-based logic such as `isOpen`)

### Reservations

- `RESERVATION_LEAD_DAYS` (default: `14`): max days ahead a user can reserve
- `RESERVATION_SLOT_BUFFER_MINUTES` (default: `5`): buffer minutes between reservation slots

### Occupancy Aggregation (occupancy_logs → occupancy_area_snapshots)

On startup, the backend can run a background loop that aggregates `occupancy_logs` into `occupancy_area_snapshots`:

- `OCCUPANCY_REALTIME_ENABLED` (default: `true`): enable/disable the aggregation task
- `OCCUPANCY_REALTIME_REFRESH_SECONDS` (default: `10`): task run interval (seconds)
- `OCCUPANCY_REALTIME_WINDOW_SECONDS` (default: `10`): aggregation window length (last N seconds)

### Camera Frame Capture (camera_sources → occupancy_logs)

On startup, the backend can run a background loop that reads camera stream URLs from the `camera_sources` table, captures one frame, runs CV inference, and writes the result to `occupancy_logs`:

- `CAMERA_CAPTURE_ENABLED` (default: `false`): enable/disable camera capture task
- `CAMERA_CAPTURE_INTERVAL_SECONDS` (default: `3`): capture loop interval (seconds)

Notes:

- Each capture writes one row into `occupancy_logs`, and sets `video_source` to the camera `name`
- Each camera must be configured in `camera_sources` with `name / stream_url / location / area / enabled`

### Authentication (JWT)

- `SECRET_KEY` (default: project built-in value): JWT signing secret
- `ALGORITHM` (default: `HS256`): JWT algorithm
- `ACCESS_TOKEN_EXPIRE_MINUTES` (default: `30`): access token expiration (minutes)

### Computer Vision (CV)

- `CV_DEVICE` (default: `auto`): device selection (e.g. `cpu`/`cuda`/`auto`)
- `CV_CONFIDENCE_THRESHOLD` (default: `0.5`): confidence threshold
- `CV_PROXIMITY_THRESHOLD` (default: `100.0`): proximity threshold
- `CV_ITEM_CLUSTER_THRESHOLD` (default: `150.0`): item cluster threshold
- `CV_SEAT_EXPANSION_FACTOR` (default: `1.5`): seat bounding-box expansion factor
- `CV_IMAGE_SIZE` (default: `640`): main model input size
- `CV_SEAT_IMAGE_SIZE` (default: `640`): seat model input size

Model weight paths are currently resolved automatically from the repository under `computer_vision/Models/...`. The env variables `CV_OCCUPANCY_MODEL_PATH` / `CV_SEAT_MODEL_PATH` are not enabled in the current version.

## Example .env

Put the following in `backend/.env`:

```env
APP_NAME=HKU Library Booking API
API_VERSION=v1
API_DEBUG=true
DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/hku_library
DEFAULT_TIMEZONE=Asia/Hong_Kong

OCCUPANCY_REALTIME_ENABLED=true
OCCUPANCY_REALTIME_REFRESH_SECONDS=10
OCCUPANCY_REALTIME_WINDOW_SECONDS=10

CAMERA_CAPTURE_ENABLED=false
CAMERA_CAPTURE_INTERVAL_SECONDS=3

SECRET_KEY=change-me
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

CV_DEVICE=auto
CV_CONFIDENCE_THRESHOLD=0.5
CV_PROXIMITY_THRESHOLD=100.0
CV_ITEM_CLUSTER_THRESHOLD=150.0
CV_SEAT_EXPANSION_FACTOR=1.5
CV_IMAGE_SIZE=640
CV_SEAT_IMAGE_SIZE=640
```

## Run

From the `backend` directory:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
