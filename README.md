# HKU Library Booking Backend

Backend service powered by **FastAPI + PostgreSQL + SQLAlchemy**. The current scope includes:

- Data modeling and table creation for libraries, facilities, users, reservations, and occupancy tracking.
- Library listing/detail APIs (with facility information).
- Facility schedule lookup that shows availability slot-by-slot.
- Reservation creation and cancellation flows.

Database support for the future real-time occupancy module is already in place; only data ingestion and APIs need to be added later.

## Project Structure

```
backend/
  app/
    core/        # Settings and database connection helpers
    models/      # SQLAlchemy ORM models
    routers/     # FastAPI routers
    schemas/     # Pydantic request/response models
    services/    # Domain logic
    main.py      # FastAPI entry point
  requirements.txt
  env.example
```

## Getting Started

1. **Create a virtual environment and install dependencies**

   ```bash
   cd backend
   python -m venv .venv
   .venv\Scripts\activate   # Windows
   pip install -r requirements.txt
   ```

2. **Configure PostgreSQL**

   - Create a database (default name `hku_library`).
   - Copy `backend/env.example` to `backend/.env` and update `DATABASE_URL` with your credentials.

3. **Run the development server**

   ```bash
   uvicorn app.main:app --reload --app-dir backend
   ```

   API docs: <http://127.0.0.1:8000/docs>

4. **(Optional) Seed demo data**

   ```bash
   cd backend
   python -m scripts.seed_data
   ```

## Core Tables

| Table | Description |
| ----- | ----------- |
| `libraries` | Library metadata (name, location, description). |
| `facilities` | Reservable resources inside libraries (rooms, seats, devices). |
| `users` | End users identified by unique email. |
| `reservations` | Bookings with time slots and status. |
| `library_occupancy_snapshots` | Near real-time seat utilization samples. |
| `library_occupancy_statistics` | Aggregated occupancy metrics (hour/day/week). |

## Available APIs (`/api/v1` prefix)

| Method | Path | Description |
| ------ | ---- | ----------- |
| GET | `/libraries` | List libraries including facility counts. |
| GET | `/libraries/{id}` | Library detail plus facilities. |
| GET | `/facilities/{id}/timeslots?date=YYYY-MM-DD` | Availability timeline for a facility on a given date. |
| POST | `/reservations` | Create a reservation (auto-creates/updates user profiles). |
| DELETE | `/reservations/{uuid}` | Cancel an existing reservation. |

**Sample reservation payload**

```json
{
  "facility_id": 1,
  "reservation_date": "2025-11-20",
  "start_time": "10:00",
  "end_time": "12:00",
  "user_full_name": "Student A",
  "user_email": "studenta@example.com",
  "notes": "Group study"
}
```

## Next Steps (Occupancy Module)

- Build a scheduler or ingestion service that records seat usage every five minutes into `library_occupancy_snapshots`.
- Aggregate snapshots into hourly/daily/weekly stats inside `library_occupancy_statistics`.
- Expose public APIs for real-time occupancy and historical trends.