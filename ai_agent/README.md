# HKU Library AI Agent

This service powers the conversational booking flow used by the backend AI endpoints. The current backend integration talks to [`api_server.py`](./api_server.py), not the older FastMCP prototype in [`server.py`](./server.py).

## What This Service Does

- keeps one in-memory conversation session per user
- uses an OpenAI-compatible chat model to collect booking details
- queries the local PostgreSQL-backed booking data through [`booking_system.py`](./booking_system.py)
- returns a booking preview and lets the backend perform the final confirmation write

The actual reservation is committed by the backend confirmation flow. In [`api_server.py`](./api_server.py), the agent is wrapped in a backend-safe mode so it stops at "ready for confirmation".

## Main Files

- [`api_server.py`](./api_server.py): FastAPI app and internal HTTP API
- [`booking_agent.py`](./booking_agent.py): LLM-driven collection logic
- [`booking_system.py`](./booking_system.py): database lookup helpers
- [`facility_mapping.py`](./facility_mapping.py): library and room-type mappings
- [`env.example`](./env.example): local environment template

## Prerequisites

- Python 3.10+
- a running PostgreSQL database with the backend schema and seed data
- a working backend `.env`, because [`booking_system.py`](./booking_system.py) loads `backend/.env` for `DATABASE_URL`
- an OpenAI-compatible API key

There is currently no dedicated `ai_agent/requirements.txt`. The simplest local setup is:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
pip install openai
```

## Configuration

Copy the example file and fill in the LLM settings:

```bash
cp ai_agent/env.example ai_agent/.env
```

Most important variables:

- `AI_API_KEY`: required
- `AI_BASE_URL`: provider base URL such as `https://api.deepseek.com` or `https://api.openai.com/v1`
- `AI_MODEL`: model name for that provider
- `AI_AGENT_HOST`: defaults to `127.0.0.1`
- `AI_AGENT_PORT`: defaults to `8001`
- `AI_AGENT_SHARED_SECRET`: should match `AI_AGENT_SHARED_SECRET` in `backend/.env`
- `AI_AGENT_SESSION_TIMEOUT_MINUTES`: in-memory session expiry

## Run Locally

From the repository root:

```bash
cd ai_agent
python api_server.py
```

Default URLs:

- health: `http://127.0.0.1:8001/health`
- internal API base: `http://127.0.0.1:8001/internal/v1`

## Internal API

These endpoints are intended for the backend service, not the mobile app directly:

- `POST /internal/v1/sessions`
- `POST /internal/v1/sessions/{session_id}/messages`
- `GET /internal/v1/sessions/{session_id}`
- `POST /internal/v1/sessions/{session_id}/reset`
- `DELETE /internal/v1/sessions/{session_id}`

When `AI_AGENT_SHARED_SECRET` is non-empty, requests must include `X-Internal-Service-Token`.

## Backend Integration

The FastAPI backend uses:

- `AI_AGENT_BASE_URL` in [`backend/app/core/config.py`](../backend/app/core/config.py)
- [`backend/app/routers/ai.py`](../backend/app/routers/ai.py)
- [`backend/app/services/ai_orchestration_service.py`](../backend/app/services/ai_orchestration_service.py)

Recommended local pairing:

- backend on `http://127.0.0.1:8000`
- AI agent on `http://127.0.0.1:8001`

## Notes

- Sessions are stored in process memory, so restarting the service clears them.
- [`server.py`](./server.py) is a legacy FastMCP implementation and is not the path the current backend uses.
- If facility matching fails, check the mappings in [`facility_mapping.py`](./facility_mapping.py) and the seeded facilities in the database.
