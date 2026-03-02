# HKU Library Booking System

A full-stack mobile application for booking library facilities and monitoring real-time space availability at HKU.

**Tech Stack:**
*   **Frontend:** Flutter (iOS & Android)
*   **Backend:** FastAPI (Python)
*   **Database:** PostgreSQL

---

## 🚀 Getting Started

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install)
*   [Python 3.10+](https://www.python.org/downloads/)
*   [PostgreSQL](https://www.postgresql.org/download/)

### 1. Backend Setup (FastAPI)

The backend handles data persistence, booking logic, and API endpoints.

1.  **Navigate to the backend directory:**
    ```bash
    cd backend
    ```

2.  **Create and activate a virtual environment:**
    *   **Using Conda (Recommended):**
        ```bash
        conda create -n hku-lib python=3.11
        conda activate hku-lib
        ```
    *   **Using venv:**
        ```bash
        python -m venv .venv
        source .venv/bin/activate  # Windows: .venv\Scripts\activate
        ```

3.  **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

4.  **Configure Environment:**
    *   Copy the example config: `cp env.example .env`
    *   Edit `.env` and set your `DATABASE_URL` (e.g., `postgresql+psycopg://user:password@localhost:5432/hku_library`).

5.  **Run the Server:**
    ```bash
    uvicorn app.main:app --reload
    ```
    The API will be available at `http://127.0.0.1:8000`.
    API Docs: `http://127.0.0.1:8000/docs`

### 2. Frontend Setup (Flutter)

The frontend is a mobile app built with Flutter.

1.  **Navigate to the frontend directory:**
    ```bash
    cd frontend
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the App:**
    *   **iOS Simulator:** `open -a Simulator` then `flutter run`
    *   **Android Emulator:** Start via Android Studio, then `flutter run`

    *Note: For Android Emulator, the API URL is automatically handled as `10.0.2.2`. For iOS, it uses `localhost`.*

---

## 📂 Project Structure

```
.
├── backend/             # FastAPI Backend
│   ├── app/
│   │   ├── models/      # Database Models
│   │   ├── routers/     # API Endpoints
│   │   └── main.py      # Entry point
│   └── requirements.txt
│
├── frontend/            # Flutter App
│   ├── lib/
│   │   ├── services/    # API Services
│   │   └── main.dart    # UI Entry point
│   └── pubspec.yaml
```

## ✨ Features

*   **Library Listing:** View available libraries and facilities.
*   **Booking System:** Reserve rooms and desks.
*   **Real-time Monitoring:** (Coming Soon) View live occupancy.
