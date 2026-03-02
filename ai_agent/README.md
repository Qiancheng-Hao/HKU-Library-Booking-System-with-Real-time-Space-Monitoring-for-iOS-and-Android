# HKU Library AI Booking Agent

This directory contains an AI-powered booking agent for the HKU Library room reservation system. It allows users to make bookings through natural language conversations.

## Architecture Overview

The agent is built with a multi-layered architecture:

1.  **`server.py`**: A FastMCP server that exposes the booking functionality as tools over HTTP. It handles session management for multiple concurrent users.
2.  **`booking_agent.py`**: The core AI logic. It uses a Large Language Model (via GitHub Models) to understand user intent, collect required information, and call the appropriate tools.
3.  **`booking_system.py`**: The database interaction layer. It translates the agent's requests into database operations, performing validations and executing reservations.
4.  **`facility_mapping.py`**: A static mapping layer that translates natural language (e.g., "Chi Wah") into the legacy system codes and room ranges used by the agent logic.

## ⚠️ Critical: Location and Facility Mapping

The AI agent relies on several hardcoded mappings to bridge natural language, legacy codes, and your local database records. **If your local database setup differs from the default, the agent will fail to find facilities or create bookings.**

### 1. Library ID Mapping (`booking_system.py`)
Inside the `OptimizedBookingSystem` class, there is a `library_id_map`:

```python
self.library_id_map = {
    "5": 1,  # Chi Wah Learning Commons -> Database Library ID 1
    "3": 2,  # Main Library -> Database Library ID 2
    "6": 3,  # Law Library -> Database Library ID 3
}
```

**Action Required**: Ensure the integer values (1, 2, 3) match the actual `id` columns in your `libraries` table in PostgreSQL. If Chi Wah is ID 10 in your database, you must update this map to `"5": 10`.

### 2. Location & Room Type Codes (`facility_mapping.py`)
This file contains the translation logic from user input to codes:
- `LOCATION_MAP`: Maps library names/aliases to legacy codes (e.g., "Chi Wah" -> "5").
- `TYPE_MAP`: Maps legacy codes and room names to type codes (e.g., "study room" at Chi Wah -> "29").
- `ROOM_RANGES`: Defines which room numbers are valid for each facility type.

**Action Required**: If you add new libraries or change how rooms are categorized, you must update these dictionaries to reflect the changes.

### 3. Room Naming Convention
The agent searches for rooms by name (e.g., "258"). The `booking_system.py` tries various patterns like "Room 258" or "Discussion Room 258" to find a match in the `facilities` table. Ensure your database facility names follow these patterns.

## Getting Started

### Prerequisites
- Python 3.10+
- A GitHub Personal Access Token (for access to GitHub Models/OpenAI)
- Local PostgreSQL database running with the backend schema

### Installation
1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
2. Set up your environment variables (GitHub Token).

### Running the Agent Server
Start the FastMCP server:
```bash
python server.py
```
The server will start on `http://localhost:8000`.

## API Tools

The server exposes the following MCP tools:

- `create_session(github_token, user_id)`: Initializes a new conversation session for a specific user.
- `chat_with_agent(session_id, message)`: Sends a natural language message to the agent.
- `get_session_status(session_id)`: Retrieves collected booking info and session metadata.
- `reset_session(session_id)`: Clears collected booking data but keeps the session alive.
- `end_session(session_id)`: Terminates the session and cleans up resources.
- `list_active_sessions()`: Returns a list of all currently active sessions.

## Typical Workflow
1. Call `create_session` with your GitHub token and the user's UUID.
2. Send messages via `chat_with_agent`.
3. The agent will ask for:
   - Library Location
   - Room Type
   - Date & Time
   - Specific Room Number(s)
4. Once all info is collected, the agent will automatically attempt to execute the booking in the database.
