import logging
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


def _env_flag(name: str, default: str = "true") -> bool:
    return os.getenv(name, default).strip().lower() in {"1", "true", "yes", "on"}


def _resolve_log_file_path() -> str:
    configured_path = os.getenv("AI_AGENT_LOG_FILE_PATH", "logs/ai_agent.log").strip()
    if os.path.isabs(configured_path):
        return configured_path
    return os.path.join(os.path.dirname(__file__), configured_path)


def _configure_logging() -> logging.Logger:
    logger = logging.getLogger("ai_agent")
    if logger.handlers:
        return logger

    logger.setLevel(logging.INFO)
    logger.propagate = False

    if not _env_flag("AI_AGENT_LOG_ENABLED", "true"):
        logger.addHandler(logging.NullHandler())
        return logger

    log_file_path = _resolve_log_file_path()
    log_dir = os.path.dirname(log_file_path)
    if log_dir:
        os.makedirs(log_dir, exist_ok=True)

    formatter = logging.Formatter(
        "%(asctime)s %(levelname)s %(name)s %(message)s"
    )

    file_handler = logging.FileHandler(
        log_file_path,
        mode="w",
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)

    logger.info("logging_configured log_file=%s", log_file_path)
    return logger


LOGGER = _configure_logging().getChild("api_server")

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
        if expired_ids:
            LOGGER.info("cleanup_expired_sessions removed_session_ids=%s", expired_ids)


cleanup_thread = threading.Thread(target=cleanup_expired_sessions, daemon=True)
cleanup_thread.start()


def verify_internal_token(x_internal_service_token: str | None = Header(default=None)) -> None:
    if INTERNAL_SHARED_SECRET and x_internal_service_token != INTERNAL_SHARED_SECRET:
        LOGGER.warning("verify_internal_token_failed token_provided=%s", x_internal_service_token is not None)
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

def _llm_http_exception(exc: Exception) -> HTTPException | None:
    try:
        from openai import APIConnectionError, APIError, APIStatusError, APITimeoutError
    except ImportError:
        return None

    if isinstance(exc, APITimeoutError):
        return HTTPException(status_code=504, detail="LLM provider request timed out.")
    if isinstance(exc, APIConnectionError):
        return HTTPException(status_code=503, detail="LLM provider is unreachable.")
    if isinstance(exc, APIStatusError):
        status_code = exc.status_code
        detail = f"LLM provider returned HTTP {status_code}."
        if status_code >= 500:
            return HTTPException(status_code=503, detail=detail)
        return HTTPException(status_code=502, detail=detail)
    if isinstance(exc, APIError):
        return HTTPException(status_code=502, detail="LLM provider request failed.")
    return None

def _build_safe_agent(user_id: str):
    from booking_agent import BookingAgent

    class BackendSafeBookingAgent(BookingAgent):
        def _execute_booking(self) -> str:
            missing = [key for key, value in self.collected_info.items() if value is None]
            if missing:
                return f"Cannot execute booking. Missing information: {', '.join(missing)}"
            return "Booking details are ready. Please confirm through the backend service."

    LOGGER.info("build_safe_agent user_id=%s", user_id)
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


def _detect_booking_change_fields(message: str) -> list[str]:
    normalized = message.strip().lower()
    if not normalized:
        return []

    has_change_intent = re.search(
        r"\b(another|different|change|switch|swap|modify|update|replace|new|other)\b"
        r"|换|改|另|其他|其它|别的|重新",
        normalized,
    )
    if not has_change_intent:
        return []

    fields: list[str] = []

    def add(*field_names: str) -> None:
        for field_name in field_names:
            if field_name not in fields:
                fields.append(field_name)

    if re.search(r"\b(location|library|place)\b|地点|图书馆|位置", normalized):
        add("location", "type", "sessions", "rooms")
    if re.search(r"\b(type|facility|category)\b|类型|设施|房型", normalized):
        add("type", "rooms")
    if re.search(r"\b(date|day)\b|日期|哪天|明天|后天|星期|礼拜", normalized):
        add("date", "sessions", "rooms")
    if re.search(r"\b(time|slot|session|hour|period)\b|时间|时段|小时|几点", normalized):
        add("sessions", "rooms")
    if re.search(r"\b(room|rooms)\b|房间|房号", normalized):
        add("rooms")
    if not fields and re.search(
        r"\b(booking|reservation|request)\b|预约|預約|预订|預訂|预定|預定",
        normalized,
    ):
        add("location", "type", "date", "sessions", "rooms")

    return fields


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


def _detect_reply_language(session: dict[str, Any]) -> str:
    thread = session.get("thread")
    messages = getattr(thread, "messages", None)
    if not messages:
        return "en"

    for entry in reversed(messages):
        if entry.get("role") != "user":
            continue
        content = str(entry.get("content") or "")
        if re.search(r"[\u4e00-\u9fff]", content):
            return "zh"
        if content.strip():
            return "en"
    return "en"


def _build_confirmation_reply_localized(
    language: str,
    collected_info: dict[str, Any],
    booking_preview: dict[str, Any],
) -> str:
    details: list[str] = []
    if language == "zh":
        if booking_preview.get("library"):
            details.append(f"地点：{booking_preview['library']}")
        if collected_info.get("room_type"):
            details.append(f"类型：{collected_info['room_type']}")
        if booking_preview.get("date"):
            details.append(f"日期：{booking_preview['date']}")
        if booking_preview.get("time_ranges"):
            details.append(f"时间：{', '.join(booking_preview['time_ranges'])}")
        if booking_preview.get("candidate_rooms"):
            details.append(f"房间：{', '.join(booking_preview['candidate_rooms'])}")

        reply = "我已为您整理好预约信息。"
        if details:
            reply += "\n\n" + "\n".join(details)
        reply += "\n\n如果信息无误，请点击“确认预约”完成提交。"
        return reply

    if booking_preview.get("library"):
        details.append(f"Location: {booking_preview['library']}")
    if collected_info.get("room_type"):
        details.append(f"Type: {collected_info['room_type']}")
    if booking_preview.get("date"):
        details.append(f"Date: {booking_preview['date']}")
    if booking_preview.get("time_ranges"):
        details.append(f"Time: {', '.join(booking_preview['time_ranges'])}")
    if booking_preview.get("candidate_rooms"):
        details.append(f"Room: {', '.join(booking_preview['candidate_rooms'])}")

    reply = "I have prepared your booking details."
    if details:
        reply += "\n\n" + "\n".join(details)
    reply += "\n\nIf everything looks correct, please tap “Confirm Booking” to submit it."
    return reply


def _build_missing_info_reply_localized(
    language: str,
    collected_info: dict[str, Any],
    booking_preview: dict[str, Any],
    suggested_options: dict[str, list[str]],
    missing_fields: list[str],
    fallback_reply: str,
) -> str:
    if language == "zh":
        details: list[str] = []
        if booking_preview.get("library"):
            details.append(f"地点：{booking_preview['library']}")
        if collected_info.get("room_type"):
            details.append(f"类型：{collected_info['room_type']}")
        if booking_preview.get("date"):
            details.append(f"日期：{booking_preview['date']}")
        if booking_preview.get("time_ranges"):
            details.append(f"时间：{', '.join(booking_preview['time_ranges'])}")

        if missing_fields == ["rooms"]:
            available_rooms = suggested_options.get("rooms") or []
            reply = "我已找到符合条件的可用房间。"
            if details:
                reply += "\n\n" + "\n".join(details)
            if available_rooms:
                reply += f"\n\n可选房间：{', '.join(available_rooms)}。"
            reply += "\n\n请先选择一个或多个房间，然后我再为您进入确认步骤。"
            return reply

        cleaned_fallback = fallback_reply.strip()
        if cleaned_fallback:
            return cleaned_fallback

        field_labels = {
            "location": "地点",
            "room_type": "房间类型",
            "date": "日期",
            "sessions": "时间",
            "rooms": "房间",
        }
        missing_labels = [field_labels.get(field, field) for field in missing_fields]
        reply = "我还需要以下信息才能继续："
        reply += "\n\n" + "、".join(missing_labels)
        if fallback_reply:
            reply += f"\n\n{fallback_reply}"
        return reply

    details = []
    if booking_preview.get("library"):
        details.append(f"Location: {booking_preview['library']}")
    if collected_info.get("room_type"):
        details.append(f"Type: {collected_info['room_type']}")
    if booking_preview.get("date"):
        details.append(f"Date: {booking_preview['date']}")
    if booking_preview.get("time_ranges"):
        details.append(f"Time: {', '.join(booking_preview['time_ranges'])}")

    if missing_fields == ["rooms"]:
        available_rooms = suggested_options.get("rooms") or []
        reply = "I found available rooms that match your request."
        if details:
            reply += "\n\n" + "\n".join(details)
        if available_rooms:
            reply += f"\n\nAvailable rooms: {', '.join(available_rooms)}."
        reply += "\n\nPlease choose one or more rooms before moving to confirmation."
        return reply

    cleaned_fallback = fallback_reply.strip()
    if cleaned_fallback:
        return cleaned_fallback

    field_labels = {
        "location": "location",
        "room_type": "room type",
        "date": "date",
        "sessions": "time",
        "rooms": "room",
    }
    missing_labels = [field_labels.get(field, field) for field in missing_fields]
    reply = "I still need the following information before I can continue:"
    reply += "\n\n" + ", ".join(missing_labels)
    if fallback_reply:
        reply += f"\n\n{fallback_reply}"
    return reply


def _build_state_payload(session_id: str, reply: str = "") -> dict[str, Any]:
    started_at = time.perf_counter()
    session = _get_session_or_raise(session_id)
    agent = session["agent"]
    collected_info = _normalize_collected_info(agent.get_collected_info())
    missing_fields = _missing_fields(collected_info)
    suggested_options, booking_preview, warnings = _availability_payload(
        collected_info=collected_info,
        user_id=session["user_id"],
    )
    language = _detect_reply_language(session)
    reply_text = reply
    if not missing_fields:
        reply_text = _build_confirmation_reply_localized(
            language,
            collected_info,
            booking_preview,
        )
    elif missing_fields:
        reply_text = _build_missing_info_reply_localized(
            language,
            collected_info,
            booking_preview,
            suggested_options,
            missing_fields,
            reply,
        )
    payload = {
        "status": "success",
        "reply": reply_text,
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
    LOGGER.info(
        "build_state_payload session_id=%s elapsed_ms=%s missing_fields=%s ready_for_confirmation=%s warnings=%s",
        session_id,
        int((time.perf_counter() - started_at) * 1000),
        missing_fields,
        not missing_fields,
        len(warnings),
    )
    return payload


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
        LOGGER.info("create_session_request user_id=%s", payload.user_id)
        agent = _build_safe_agent(payload.user_id)
    except ModuleNotFoundError as exc:
        LOGGER.exception("create_session_dependency_error user_id=%s", payload.user_id)
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
    LOGGER.info(
        "create_session_success session_id=%s user_id=%s active_session_count=%s",
        session_id,
        payload.user_id,
        len(sessions),
    )
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
    started_at = time.perf_counter()
    session = _get_session_or_raise(session_id)
    agent = session["agent"]
    LOGGER.info(
        "chat_request_start session_id=%s user_id=%s message_length=%s",
        session_id,
        session["user_id"],
        len(payload.message),
    )

    try:
        if agent.agent is None:
            LOGGER.info("chat_initialize_agent session_id=%s", session_id)
            await agent.initialize_agent()

        if session["thread"] is None:
            LOGGER.info("chat_create_thread session_id=%s", session_id)
            session["thread"] = agent.agent.create_session()

        change_fields = _detect_booking_change_fields(payload.message)
        if change_fields:
            cleared_fields = agent.clear_collected_fields(change_fields)
            LOGGER.info(
                "chat_change_request_cleared_fields session_id=%s requested_fields=%s cleared_fields=%s",
                session_id,
                change_fields,
                cleared_fields,
            )

        reply = await agent.chat(payload.message, thread=session["thread"])
        LOGGER.info(
            "chat_request_done session_id=%s elapsed_ms=%s reply_length=%s",
            session_id,
            int((time.perf_counter() - started_at) * 1000),
            len(reply),
        )
        return _build_state_payload(session_id, reply=reply)
    except HTTPException:
        raise
    except Exception as exc:
        LOGGER.exception(
            "chat_request_failed session_id=%s elapsed_ms=%s",
            session_id,
            int((time.perf_counter() - started_at) * 1000),
        )
        llm_error = _llm_http_exception(exc)
        if llm_error is not None:
            raise llm_error from exc
        raise


@app.get("/internal/v1/sessions/{session_id}")
def get_session_status_endpoint(
    session_id: str,
    _: None = Depends(verify_internal_token),
) -> dict[str, Any]:
    LOGGER.info("get_session_status_request session_id=%s", session_id)
    return _build_state_payload(session_id)


@app.post("/internal/v1/sessions/{session_id}/reset")
def reset_session_endpoint(
    session_id: str,
    _: None = Depends(verify_internal_token),
) -> dict[str, Any]:
    session = _get_session_or_raise(session_id)
    LOGGER.info("reset_session_request session_id=%s user_id=%s", session_id, session["user_id"])
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
    LOGGER.info("end_session_success session_id=%s", session_id)
    return {
        "status": "success",
        "message": "Session ended successfully.",
    }


if __name__ == "__main__":
    LOGGER.info("api_server_start host=%s port=%s", SERVER_HOST, SERVER_PORT)
    uvicorn.run(app, host=SERVER_HOST, port=SERVER_PORT)
