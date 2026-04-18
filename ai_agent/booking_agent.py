import inspect
import json
import logging
import uuid
from typing import Annotated, Optional, Dict, Any, get_type_hints
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from openai import AsyncOpenAI

from booking_system import OptimizedBookingSystem
from facility_mapping import (
    get_location_code,
    get_room_type_code,
    get_room_range_suggestions,
    LOCATION_NAMES,
    TYPE_NAMES
)
import threading
import time
import os
from dotenv import load_dotenv

load_dotenv()

LOGGER = logging.getLogger("ai_agent.booking_agent")

class _Session:
    """Holds the conversation message history for one session."""

    def __init__(self, system_prompt: str):
        self.messages: list[dict] = [{"role": "system", "content": system_prompt}]


class _AgentResponse:
    def __init__(self, text: str):
        self.text = text


class _SimpleAgent:
    """
    Tool-calling agent loop built on top of the standard OpenAI
    Chat Completions API — compatible with any OpenAI-compatible provider.
    """

    MAX_ITERATIONS = 10  # max tool-call rounds per user message

    def __init__(
        self,
        client: AsyncOpenAI,
        model: str,
        instructions: str,
        tools: list,
    ):
        self._client = client
        self._model = model
        self._instructions = instructions
        self._tool_funcs: dict[str, Any] = {fn.__name__: fn for fn in tools}
        self._tool_schemas: list[dict] = self._build_schemas(tools)

    def create_session(self) -> _Session:
        return _Session(self._instructions)

    @staticmethod
    def _build_schemas(tools: list) -> list[dict]:
        """Convert method signatures into OpenAI function-call schemas."""
        schemas = []
        for fn in tools:
            sig = inspect.signature(fn)
            properties: dict = {}
            required: list[str] = []

            for name, param in sig.parameters.items():
                if name == "self":
                    continue
                annotation = param.annotation
                description = ""
                # Extract description from Annotated[type, "description"]
                if hasattr(annotation, "__metadata__") and annotation.__metadata__:
                    description = str(annotation.__metadata__[0])
                properties[name] = {"type": "string", "description": description}
                if param.default is inspect.Parameter.empty:
                    required.append(name)

            schemas.append({
                "type": "function",
                "function": {
                    "name": fn.__name__,
                    "description": next(iter((fn.__doc__ or "").strip().splitlines()), ""),
                    "parameters": {
                        "type": "object",
                        "properties": properties,
                        "required": required,
                    },
                },
            })
        return schemas

    async def run(self, message: str, session: _Session) -> _AgentResponse:
        started_at = time.perf_counter()
        LOGGER.info(
            "agent_run_start message_length=%s history_size=%s",
            len(message),
            len(session.messages),
        )
        session.messages.append({"role": "user", "content": message})

        for iteration in range(1, self.MAX_ITERATIONS + 1):
            kwargs: dict = {
                "model": self._model,
                "messages": session.messages,
            }
            if self._tool_schemas:
                kwargs["tools"] = self._tool_schemas
                kwargs["tool_choice"] = "auto"

            llm_started_at = time.perf_counter()
            LOGGER.info(
                "agent_llm_request_start iteration=%s model=%s message_count=%s",
                iteration,
                self._model,
                len(session.messages),
            )
            response = await self._client.chat.completions.create(**kwargs)
            LOGGER.info(
                "agent_llm_request_done iteration=%s elapsed_ms=%s",
                iteration,
                int((time.perf_counter() - llm_started_at) * 1000),
            )
            msg = response.choices[0].message

            # Add assistant turn to history
            assistant_entry: dict = {"role": "assistant", "content": msg.content}
            if msg.tool_calls:
                assistant_entry["tool_calls"] = [tc.model_dump() for tc in msg.tool_calls]
            session.messages.append(assistant_entry)

            # No tool calls → final reply
            if not msg.tool_calls:
                LOGGER.info(
                    "agent_run_done iteration=%s elapsed_ms=%s response_length=%s",
                    iteration,
                    int((time.perf_counter() - started_at) * 1000),
                    len(msg.content or ""),
                )
                return _AgentResponse(msg.content or "")

            # Execute each tool call and append results
            LOGGER.info(
                "agent_tool_calls iteration=%s tool_count=%s",
                iteration,
                len(msg.tool_calls),
            )
            for tc in msg.tool_calls:
                fn = self._tool_funcs.get(tc.function.name)
                tool_started_at = time.perf_counter()
                if fn is None:
                    result = f"Unknown tool: {tc.function.name}"
                    LOGGER.warning(
                        "agent_tool_unknown iteration=%s tool=%s",
                        iteration,
                        tc.function.name,
                    )
                else:
                    try:
                        args = json.loads(tc.function.arguments or "{}")
                        LOGGER.info(
                            "agent_tool_start iteration=%s tool=%s args=%s",
                            iteration,
                            tc.function.name,
                            args,
                        )
                        result = fn(**args)
                        if inspect.iscoroutine(result):
                            result = await result
                        result = str(result)
                        LOGGER.info(
                            "agent_tool_done iteration=%s tool=%s elapsed_ms=%s result_length=%s",
                            iteration,
                            tc.function.name,
                            int((time.perf_counter() - tool_started_at) * 1000),
                            len(result),
                        )
                    except Exception as exc:
                        result = f"Tool error: {exc}"
                        LOGGER.exception(
                            "agent_tool_failed iteration=%s tool=%s elapsed_ms=%s",
                            iteration,
                            tc.function.name,
                            int((time.perf_counter() - tool_started_at) * 1000),
                        )

                session.messages.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "content": result,
                })

        # Exceeded max iterations — return whatever the last assistant message was
        for entry in reversed(session.messages):
            if entry.get("role") == "assistant" and entry.get("content"):
                LOGGER.warning(
                    "agent_run_max_iterations elapsed_ms=%s response_length=%s",
                    int((time.perf_counter() - started_at) * 1000),
                    len(entry["content"]),
                )
                return _AgentResponse(entry["content"])
        LOGGER.warning(
            "agent_run_empty_response elapsed_ms=%s",
            int((time.perf_counter() - started_at) * 1000),
        )
        return _AgentResponse("")


# ---------------------------------------------------------------------------
# BookingAgent
# ---------------------------------------------------------------------------

class BookingAgent:
    """
    AI Agent that interacts with users to collect booking information
    and executes the booking process directly in the database.
    The agent collects:
    - Location: Library location code
    - Type: Room type code
    - Room numbers: List of room IDs to attempt booking
    - Date: Booking date in YYYYMMDD format
    - Sessions: Time session codes
    """

    def __init__(self, api_key: str = "", user_id: Optional[str] = None, model_id: str = ""):
        """
        Initialize the booking agent.
        Args:
            api_key: API key for the LLM provider (reads AI_API_KEY from env if not provided)
            user_id: The UUID of the user (optional during initialization)
            model_id: The model ID to use (reads AI_MODEL from env if not provided)
        """
        self.api_key = api_key or os.environ.get("AI_API_KEY", "")
        self.model_id = model_id or os.environ.get("AI_MODEL", "deepseek-chat")
        self.base_url = os.environ.get("AI_BASE_URL", "https://api.deepseek.com")
        self.timeout_seconds = float(os.environ.get("AI_TIMEOUT_SECONDS", "180"))
        self.timezone_name = os.environ.get("AI_AGENT_TIMEZONE", "Asia/Hong_Kong")
        self.user_id = uuid.UUID(user_id) if user_id else None
        self.agent: Optional[_SimpleAgent] = None
        self.collected_info: Dict[str, Any] = {
            "location": None,
            "type": None,
            "rooms": None,
            "date": None,
            "sessions": None,
        }

    async def initialize_agent(self):
        """Initialize the AI agent with the configured LLM provider and tools."""
        today = self._current_local_date().isoformat()
        LOGGER.info(
            "booking_agent_initialize_start user_id=%s model=%s base_url=%s timeout_seconds=%s timezone=%s today=%s",
            self.user_id,
            self.model_id,
            self.base_url,
            self.timeout_seconds,
            self.timezone_name,
            today,
        )
        client = AsyncOpenAI(
            base_url=self.base_url,
            api_key=self.api_key,
            timeout=self.timeout_seconds,
        )

        instructions = f"""
        You are a booking assistant for HKU Library. Your job is to collect booking information from users and execute the booking.
        IMPORTANT: Users provide information in NATURAL LANGUAGE (names, not codes). You must convert names to codes using the conversion tools.
        ═══════════════════════════════════════════════════════════════
        INFORMATION YOU NEED TO COLLECT FROM USERS:
        ═══════════════════════════════════════════════════════════════
        1. LOCATION (library name):
        - User will say: "Chi Wah", "Main Library", "Law Library", etc.
        - You must: Call _convert_location() to convert name → code
        2. ROOM TYPE (facility type name):
        - User will say: "study room", "discussion room", "computer", etc.
        - You must: Call _convert_room_type() to convert name → code
        3. DATE (booking date):
        - User will say: "tomorrow", "December 28", "next Monday", etc.
        - You must: Convert to YYYYMMDD format and call _collect_date()
        - Today is {today} in timezone {self.timezone_name}
        4. TIME SESSIONS (time slots):
        - User will say: "8 to 9 AM", "morning", "8:00-9:00", etc.
        - If the user gives vague phrases (morning/afternoon/evening), ask a follow-up question for exact start and end time first.
        - Only after explicit time is provided, convert to session code format and call _collect_sessions()
        - Format: "HHMM" + "HHMM" (start time + end time in 24-hour format)
        5. ROOM NUMBERS (the actual room numbers they want):
        - User will say: "258" or "room 258" or "258 to 267" or "258, 259, 260"
        - You must: Call _collect_rooms() directly with the numbers
        ═══════════════════════════════════════════════════════════════
        CRITICAL WORKFLOW - FOLLOW THESE STEPS EXACTLY:
        ═══════════════════════════════════════════════════════════════
        STEP 1: When user mentions a LOCATION NAME → call _convert_location(location_name)
        STEP 2: When user mentions a ROOM TYPE NAME → call _convert_room_type(room_type_name)
        STEP 3: When user mentions DATE → Convert to YYYYMMDD format and call _collect_date(date)
        STEP 4: When user mentions TIME
        - If time is vague, ask for explicit start and end time.
        - If time is explicit, convert to session code format (HHMMHHMM) and call _collect_sessions(sessions)

        STEP 5 (ACTIVE RECOMMENDATION):
        - Once you have Location, Type, Date, and Time, IMMEDIATELY call _query_available_facilities()
        - Show the user the available rooms and ask them to pick one or more.
        - If the user has already specified a room, still call it to verify if it's available.

        STEP 6: When user confirms room(s) → call _collect_rooms(rooms)
        STEP 7: When user says "book", "confirm", or "yes" → call _execute_booking() if complete
        ═══════════════════════════════════════════════════════════════
        AVAILABLE TOOLS:
        ═══════════════════════════════════════════════════════════════
        - _convert_location(location_name) - Convert location name to code
        - _convert_room_type(room_type_name) - Convert room type name to code
        - _collect_rooms(rooms) - Store room numbers
        - _collect_date(date) - Store booking date (YYYYMMDD)
        - _collect_sessions(sessions) - Store time sessions (HHMMHHMM)
        - _query_available_facilities() - Check which rooms are actually free and recommend them
        - _check_information_complete() - Check what's missing
        - _execute_booking() - Execute the actual booking in the database
        ═══════════════════════════════════════════════════════════════
        """

        self.agent = _SimpleAgent(
            client=client,
            model=self.model_id,
            instructions=instructions,
            tools=[
                self._convert_location,
                self._convert_room_type,
                self._collect_rooms,
                self._collect_date,
                self._collect_sessions,
                self._query_available_facilities,
                self._check_information_complete,
                self._execute_booking,
            ],
        )
        LOGGER.info(
            "booking_agent_initialize_done user_id=%s tool_count=%s",
            self.user_id,
            len(self.agent._tool_funcs),
        )

    def _current_local_date(self):
        """Return the current date in the configured booking timezone."""
        try:
            tz = ZoneInfo(self.timezone_name)
        except ZoneInfoNotFoundError:
            LOGGER.warning(
                "booking_agent_invalid_timezone timezone=%s fallback=Asia/Hong_Kong",
                self.timezone_name,
            )
            tz = ZoneInfo("Asia/Hong_Kong")
        return datetime.now(tz).date()

    def set_user_id(self, user_id: str) -> None:
        """Set the user ID for this agent."""
        self.user_id = uuid.UUID(user_id)

    def _query_available_facilities(self) -> str:
        """Query currently available facilities based on collected location, type, date and sessions."""
        started_at = time.perf_counter()
        if not all([self.collected_info["location"], self.collected_info["type"],
                   self.collected_info["date"], self.collected_info["sessions"]]):
            LOGGER.info(
                "availability_query_skipped missing_fields=%s",
                [key for key, value in self.collected_info.items() if value is None],
            )
            return "Need location, type, date, and sessions to check availability."

        try:
            LOGGER.info(
                "availability_query_start user_id=%s location=%s type=%s date=%s sessions=%s",
                self.user_id,
                self.collected_info["location"],
                self.collected_info["type"],
                self.collected_info["date"],
                self.collected_info["sessions"],
            )
            dummy_id = self.user_id or uuid.uuid4()
            booking_system = OptimizedBookingSystem(
                user_id=dummy_id,
                location=self.collected_info["location"],
                type_code=self.collected_info["type"],
                date_str=self.collected_info["date"],
                sessions=self.collected_info["sessions"]
            )
            result = booking_system.get_available_facilities()
            if result["success"]:
                LOGGER.info(
                    "availability_query_done elapsed_ms=%s available_session_count=%s",
                    int((time.perf_counter() - started_at) * 1000),
                    len(result.get("available_facilities", {})),
                )
                diagnostics = result.get("session_diagnostics", {})
                adjusted_entries = []
                for session, diag in diagnostics.items():
                    adjusted = diag.get("adjusted_time_range")
                    if adjusted:
                        requested = diag.get("requested_time_range") or (
                            f"{session[:2]}:{session[2:4]}-{session[4:6]}:{session[6:8]}"
                        )
                        adjusted_entries.append((requested, adjusted))

                if adjusted_entries:
                    # Force explicit time collection after any opening-hours adjustment.
                    self.collected_info["sessions"] = None
                    hints = "\n".join(
                        f"- Requested {requested} -> can only search within {adjusted}"
                        for requested, adjusted in adjusted_entries
                    )
                    return (
                        "Your requested time is outside opening hours, so I did not continue with an implicit adjustment.\n"
                        f"{hints}\n\n"
                        "Please provide your exact start and end time within opening hours "
                        "(for example: 09:00-11:00)."
                    )

                msg = f"Available rooms for {result['date']}:\n"
                for session, rooms in result["available_facilities"].items():
                    time_str = f"{session[:2]}:{session[2:4]}-{session[4:6]}:{session[6:8]}"
                    diag = diagnostics.get(session, {})
                    adjusted_time = diag.get("adjusted_time_range")
                    display_time = (
                        f"{time_str} (adjusted to {adjusted_time})"
                        if adjusted_time
                        else time_str
                    )
                    if rooms:
                        msg += f"- {display_time}: {', '.join(rooms)}\n"
                    else:
                        reason = diag.get("reason")
                        if reason == "outside_opening_hours":
                            msg += f"- {display_time}: No rooms available (requested time is outside opening hours).\n"
                        elif reason == "fully_booked":
                            msg += f"- {display_time}: No rooms available (all matching facilities are booked).\n"
                        else:
                            msg += f"- {display_time}: No rooms available.\n"
                return msg
            else:
                LOGGER.warning(
                    "availability_query_failed elapsed_ms=%s message=%s",
                    int((time.perf_counter() - started_at) * 1000),
                    result.get("message", "Unknown error"),
                )
                return f"Failed to query availability: {result.get('message', 'Unknown error')}"
        except Exception as e:
            LOGGER.exception(
                "availability_query_exception elapsed_ms=%s",
                int((time.perf_counter() - started_at) * 1000),
            )
            return f"Error checking availability: {str(e)}"

    def _convert_location(self, location_name: Annotated[str, "Library location name in natural language (e.g., 'Chi Wah', 'Main Library')"]) -> str:
        """Convert natural language location name to location code."""
        code, message = get_location_code(location_name)
        if code:
            self.collected_info["location"] = code
            return f" {message}"
        else:
            return f"{message}\n\nAvailable locations: {', '.join(LOCATION_NAMES)}"

    def _convert_room_type(self, room_type_name: Annotated[str, "Room type name in natural language (e.g., 'study room', 'discussion room')"]) -> str:
        """Convert natural language room type name to type code."""
        location_code = self.collected_info.get("location")
        if not location_code:
            return "Please specify location first before selecting room type."
        code, message = get_room_type_code(location_code, room_type_name)
        if code:
            self.collected_info["type"] = code
            range_info = get_room_range_suggestions(location_code, code)
            return f" {message}\n{range_info}"
        else:
            return f"{message}\n\nPlease check available room types for the selected location."

    def _collect_rooms(self, rooms: Annotated[str, "Room numbers (e.g., '258', '258-267')"]) -> str:
        """Collect and store the room numbers."""
        room_list = []
        for part in rooms.split(','):
            part = part.strip()
            if '-' in part:
                start, end = part.split('-')
                room_list.extend([str(r) for r in range(int(start), int(end) + 1)])
            else:
                room_list.append(part)
        self.collected_info["rooms"] = room_list
        return f"Room numbers recorded: {', '.join(room_list)}."

    def _collect_date(self, date: Annotated[str, "Booking date in YYYYMMDD format"]) -> str:
        """Collect and store the booking date."""
        try:
            datetime.strptime(date, "%Y%m%d")
            self.collected_info["date"] = date
            return f"Date recorded: {date[:4]}-{date[4:6]}-{date[6:8]}"
        except ValueError:
            return "Invalid date format. Please use YYYYMMDD."

    def _collect_sessions(self, sessions: Annotated[str, "Time session codes (HHMMHHMM)"]) -> str:
        """Collect and store the time session codes."""
        session_list = [s.strip() for s in sessions.split(',')]
        self.collected_info["sessions"] = session_list
        return f"Time sessions recorded: {sessions}."

    def _check_information_complete(self) -> str:
        """Check if all required information has been collected."""
        missing = [k for k, v in self.collected_info.items() if v is None]
        if missing:
            return f"Missing information: {', '.join(missing)}."
        return "All required information has been collected. Ready to proceed with booking."

    def _execute_booking(self) -> str:
        """Signal that all booking details are collected and ready for confirmation."""
        missing = [k for k, v in self.collected_info.items() if v is None]
        if missing:
            return f"Cannot execute booking. Missing information: {', '.join(missing)}"
        return "Booking details are ready. Please confirm through the backend service."

    async def chat(self, user_message: str, thread=None) -> str:
        """Process a user message and return the agent's response."""
        started_at = time.perf_counter()
        LOGGER.info(
            "booking_agent_chat_start user_id=%s message_length=%s has_thread=%s",
            self.user_id,
            len(user_message),
            thread is not None,
        )
        if self.agent is None:
            await self.initialize_agent()
        assert self.agent is not None

        if thread is None:
            thread = self.agent.create_session()

        response = await self.agent.run(user_message, session=thread)
        LOGGER.info(
            "booking_agent_chat_done user_id=%s elapsed_ms=%s response_length=%s",
            self.user_id,
            int((time.perf_counter() - started_at) * 1000),
            len(response.text or ""),
        )
        return response.text or ""

    def reset(self):
        """Reset all collected information."""
        self.collected_info = {
            "location": None,
            "type": None,
            "rooms": None,
            "date": None,
            "sessions": None,
        }

    def clear_collected_fields(self, fields: list[str]) -> list[str]:
        """Clear selected collected fields and return the fields that changed."""
        cleared: list[str] = []
        for field in fields:
            if field in self.collected_info:
                self.collected_info[field] = None
                cleared.append(field)
        return cleared

    def get_collected_info(self) -> Dict[str, Any]:
        """Get the currently collected information."""
        return self.collected_info.copy()

