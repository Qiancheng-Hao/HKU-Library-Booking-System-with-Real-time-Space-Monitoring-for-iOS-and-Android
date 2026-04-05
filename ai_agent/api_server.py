import os
import re
import threading
import time
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import uvicorn
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from booking_system import OptimizedBookingSystem
from facility_mapping import LOCATION_NAMES, TYPE_NAMES

load_dotenv()

app = FastAPI(title="HKU Library AI Agent API")

sessions: dict[str, dict[str, Any]] = {}
sessions_lock = threading.Lock()

SESSION_TIMEOUT_MINUTES = int(os.getenv("AI_AGENT_SESSION_TIMEOUT_MINUTES", "30"))
CLEANUP_INTERVAL_SECONDS = int(os.getenv("AI_AGENT_CLEANUP_INTERVAL_SECONDS", "300"))
INTERNAL_SHARED_SECRET = os.getenv("AI_AGENT_SHARED_SECRET", "")
SERVER_HOST = os.getenv("AI_AGENT_HOST", "127.0.0.1")
SERVER_PORT = int(os.getenv("AI_AGENT_PORT", "8001"))


class SessionCreateRequest(BaseModel):
    user_id: str


class SessionMessageRequest(BaseModel):
    message: str = Field(min_length=1)


def cleanup_expired_sessions() -> None:
    while True:
        time.sleep(CLEANUP_INTERVAL_SECONDS)
        now = datetime.now(timezone.utc)
        expired_ids: list[str] = []
        with sessions_lock:
            for session_id, session_data in sessions.items():
                if session_data["expires_at"] <= now:
                    expired_ids.append(session_id)
            for session_id in expired_ids:
                del sessions[session_id]


cleanup_thread = threading.Thread(target=cleanup_expired_sessions, daemon=True)
cleanup_thread.start()


def verify_internal_token(x_internal_service_token: str | None = Header(default=None)) -> None:
    if INTERNAL_SHARED_SECRET and x_internal_service_token != INTERNAL_SHARED_SECRET:
        raise HTTPException(status_code=401, detail="Invalid internal service token.")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _get_session_or_raise(session_id: str) -> dict[str, Any]:
    with sessions_lock:
        session = sessions.get(session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Invalid or expired session.")
        session["last_activity"] = _now()
        session["expires_at"] = _now() + timedelta(minutes=SESSION_TIMEOUT_MINUTES)
        return session


def _build_safe_agent(user_id: str):
    from booking_agent import BookingAgent

    class BackendSafeBookingAgent(BookingAgent):
        def _execute_booking(self) -> str:
            missing = [key for key, value in self.collected_info.items() if value is None]
            if missing:
                return f"Cannot execute booking. Missing information: {', '.join(missing)}"
            return "Booking details are ready. Please confirm through the backend service."

    return BackendSafeBookingAgent(user_id=user_id)


def _normalize_rooms(rooms: list[str] | None) -> list[str]:
    if not rooms:
        return []
    normalized: list[str] = []
    for room in rooms:
        value = room.strip()
        match = re.search(r"([A-Za-z]*\d+|[A-Za-z]+)$", value)
        normalized.append(match.group(1) if match else value)
    return list(dict.fromkeys(normalized))


def _room_option_sort_key(room: str) -> tuple:
    value = room.strip()
    if value.isdigit():
        return (0, int(value))
    match = re.match(r"^([A-Za-z]+)(\d+)$", value)
    if match:
        prefix, number = match.groups()
        return (1, prefix.lower(), int(number))
    return (2, value.lower())


def _format_session_code(session_code: str) -> str:
    return f"{session_code[:2]}:{session_code[2:4]}-{session_code[4:6]}:{session_code[6:8]}"


def _normalize_collected_info(collected_info: dict[str, Any]) -> dict[str, Any]:
    location_code = collected_info.get("location")
    room_type_code = collected_info.get("type")
    sessions_value = collected_info.get("sessions") or []
    rooms_value = collected_info.get("rooms") or []
    return {
        "location": LOCATION_NAMES.get(location_code) if location_code else None,
        "location_code": location_code,
        "room_type": TYPE_NAMES.get(location_code, {}).get(room_type_code) if location_code and room_type_code else None,
        "room_type_code": room_type_code,
        "date": collected_info.get("date"),
        "sessions": sessions_value,
        "rooms": _normalize_rooms(rooms_value),
    }


def _missing_fields(collected_info: dict[str, Any]) -> list[str]:
    missing: list[str] = []
    if not collected_info["location_code"]:
        missing.append("location")
    if not collected_info["room_type_code"]:
        missing.append("room_type")
    if not collected_info["date"]:
        missing.append("date")
    if not collected_info["sessions"]:
        missing.append("sessions")
    if not collected_info["rooms"]:
        missing.append("rooms")
    return missing


def _availability_payload(collected_info: dict[str, Any], user_id: str) -> tuple[dict[str, list[str]], dict[str, Any], list[str]]:
    suggested_options = {
        "locations": [],
        "room_types": [],
        "rooms": [],
    }
    booking_preview = {
        "library": collected_info["location"],
        "date": None,
        "time_ranges": [_format_session_code(value) for value in collected_info["sessions"]],
        "candidate_rooms": collected_info["rooms"],
    }
    warnings: list[str] = []

    if collected_info["date"]:
        booking_preview["date"] = (
            f"{collected_info['date'][:4]}-{collected_info['date'][4:6]}-{collected_info['date'][6:8]}"
        )

    if not all(
        [
            collected_info["location_code"],
            collected_info["room_type_code"],
            collected_info["date"],
            collected_info["sessions"],
        ]
    ):
        return suggested_options, booking_preview, warnings

    try:
        booking_system = OptimizedBookingSystem(
            user_id=uuid.UUID(user_id),
            location=collected_info["location_code"],
            type_code=collected_info["room_type_code"],
            date_str=collected_info["date"],
            sessions=collected_info["sessions"],
        )
        result = booking_system.get_available_facilities()
    except Exception as exc:
        warnings.append(f"Availability query failed: {exc}")
        return suggested_options, booking_preview, warnings

    if not result.get("success"):
        warnings.append(result.get("message", "Availability query failed."))
        return suggested_options, booking_preview, warnings

    available_full_rooms: list[str] = []
    for rooms in result.get("available_facilities", {}).values():
        available_full_rooms.extend(rooms)

    # Preserve backend order while removing duplicates.
    dedup_full_rooms = list(dict.fromkeys([room.strip() for room in available_full_rooms if room and room.strip()]))

    available_short_rooms = _normalize_rooms(dedup_full_rooms)
    suggested_options["rooms"] = sorted(
        list(dict.fromkeys(available_short_rooms)),
        key=_room_option_sort_key,
    )

    # Build a best-effort mapping from short tokens (e.g., "2", "R55", "A") back to full names.
    short_to_full: dict[str, str] = {}
    for full_name, short_name in zip(dedup_full_rooms, _normalize_rooms(dedup_full_rooms)):
        short_to_full.setdefault(short_name, full_name)

    if collected_info["rooms"]:
        preview_rooms: list[str] = []
        for selected in collected_info["rooms"]:
            key = selected.strip()
            preview_rooms.append(short_to_full.get(key, selected))
        booking_preview["candidate_rooms"] = preview_rooms
    else:
        booking_preview["candidate_rooms"] = dedup_full_rooms
    return suggested_options, booking_preview, warnings


def _build_state_payload(session_id: str, reply: str = "") -> dict[str, Any]:
    session = _get_session_or_raise(session_id)
    agent = session["agent"]
    collected_info = _normalize_collected_info(agent.get_collected_info())
    missing_fields = _missing_fields(collected_info)
    suggested_options, booking_preview, warnings = _availability_payload(
        collected_info=collected_info,
        user_id=session["user_id"],
    )
    return {
        "status": "success",
        "reply": reply,
        "collected_info": collected_info,
        "missing_fields": missing_fields,
        "is_complete": not missing_fields,
        "ready_for_confirmation": not missing_fields,
        "booking_preview": booking_preview,
        "suggested_options": suggested_options,
        "warnings": warnings,
        "raw_intent": {
            "intent": "booking_request",
            "collected_info": collected_info,
        },
        "session_id": session_id,
        "user_id": session["user_id"],
        "created_at": session["created_at"],
        "last_activity": session["last_activity"],
        "expires_at": session["expires_at"],
    }


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/internal/v1/sessions")
def create_session_endpoint(
    payload: SessionCreateRequest,
    _: None = Depends(verify_internal_token),
) -> dict[str, Any]:
    if not payload.user_id:
        raise HTTPException(status_code=400, detail="user_id is required")

    try:
        agent = _build_safe_agent(payload.user_id)
    except ModuleNotFoundError as exc:
        raise HTTPException(status_code=503, detail=f"AI agent dependencies are unavailable: {exc}") from exc

    session_id = str(uuid.uuid4())
    created_at = _now()
    with sessions_lock:
        sessions[session_id] = {
            "agent": agent,
            "thread": None,
            "user_id": payload.user_id,
            "created_at": created_at,
            "last_activity": created_at,
            "expires_at": created_at + timedelta(minutes=SESSION_TIMEOUT_MINUTES),
        }
    return {
        "status": "success",
        "session_id": session_id,
        "message": "Session created successfully.",
        "created_at": created_at,
        "expires_at": created_at + timedelta(minutes=SESSION_TIMEOUT_MINUTES),
    }


@app.post("/internal/v1/sessions/{session_id}/messages")
async def chat_with_agent_endpoint(
    session_id: str,
    payload: SessionMessageRequest,
    _: None = Depends(verify_internal_token),
) -> dict[str, Any]:
    session = _get_session_or_raise(session_id)
    agent = session["agent"]

    if agent.agent is None:
        await agent.initialize_agent()

    if session["thread"] is None:
        session["thread"] = agent.agent.create_session()

    reply = await agent.chat(payload.message, thread=session["thread"])
    return _build_state_payload(session_id, reply=reply)


@app.get("/internal/v1/sessions/{session_id}")
def get_session_status_endpoint(
    session_id: str,
    _: None = Depends(verify_internal_token),
) -> dict[str, Any]:
    return _build_state_payload(session_id)


@app.post("/internal/v1/sessions/{session_id}/reset")
def reset_session_endpoint(
    session_id: str,
    _: None = Depends(verify_internal_token),
) -> dict[str, Any]:
    session = _get_session_or_raise(session_id)
    session["agent"].reset()
    session["thread"] = None
    return _build_state_payload(session_id, reply="Session data has been reset.")


@app.delete("/internal/v1/sessions/{session_id}")
def end_session_endpoint(
    session_id: str,
    _: None = Depends(verify_internal_token),
) -> dict[str, Any]:
    with sessions_lock:
        if session_id not in sessions:
            raise HTTPException(status_code=404, detail="Session not found or already ended.")
        del sessions[session_id]
    return {
        "status": "success",
        "message": "Session ended successfully.",
    }


if __name__ == "__main__":
    uvicorn.run(app, host=SERVER_HOST, port=SERVER_PORT)
