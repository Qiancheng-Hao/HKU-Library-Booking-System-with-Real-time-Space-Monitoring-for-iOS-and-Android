import uuid
from typing import Annotated, Optional, Dict, Any
from datetime import datetime
from agent_framework import ChatAgent
from agent_framework.openai import OpenAIChatClient
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
import json
import asyncio

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
    
    def __init__(self, github_token: str, user_id: Optional[str] = None, model_id: str = "openai/o4-mini"):
        """
        Initialize the booking agent.
        Args:
            github_token: GitHub personal access token for model access
            user_id: The UUID of the user (optional during initialization)
            model_id: The model ID to use
        """
        self.github_token = github_token
        self.model_id = model_id
        self.user_id = uuid.UUID(user_id) if user_id else None
        self.agent: Optional[ChatAgent] = None
        self.collected_info: Dict[str, Any] = {
            "location": None,
            "type": None,
            "rooms": None,
            "date": None,
            "sessions": None,
        }
        if not self.github_token:
            raise ValueError("GitHub token is required to initialize the BookingAgent.")
        
    async def initialize_agent(self):
        """
        Initialize the AI agent with GitHub model and tools.
        """
        openai_client = AsyncOpenAI(
            base_url="https://models.github.ai/inference",
            api_key=self.github_token,
        )
        
        chat_client = OpenAIChatClient(
            async_client=openai_client,
            model_id=self.model_id
        )
        
        # Define agent instructions
        instructions = """
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
        - Today is 2026-03-02
        4. TIME SESSIONS (time slots):
        - User will say: "8 to 9 AM", "morning", "8:00-9:00", etc.
        - You must: Convert to session code format and call _collect_sessions()
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
        STEP 4: When user mentions TIME → Convert to session code format (HHMMHHMM) and call _collect_sessions(sessions)
        
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
        # Create agent with booking tools
        self.agent = ChatAgent(
            chat_client=chat_client,
            name="BookingAgent",
            instructions=instructions,
            tools=[
                self._convert_location,
                self._convert_room_type,
                self._collect_rooms,
                self._collect_date,
                self._collect_sessions,
                self._query_available_facilities,
                self._check_information_complete,
                self._execute_booking
            ]
        )
    
    def set_user_id(self, user_id: str) -> None:
        """
        Set the user ID for this agent.
        Args: 
            user_id: The UUID string of the user
        """
        self.user_id = uuid.UUID(user_id)

    def _query_available_facilities(self) -> str:
        """
        Query currently available facilities based on collected location, type, date and sessions.
        """
        if not all([self.collected_info["location"], self.collected_info["type"], 
                   self.collected_info["date"], self.collected_info["sessions"]]):
            return "Need location, type, date, and sessions to check availability."
        
        try:
            # We use a dummy user_id for querying availability
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
                msg = f"Available rooms for {result['date']}:\n"
                for session, rooms in result["available_facilities"].items():
                    time_str = f"{session[:2]}:{session[2:4]}-{session[4:6]}:{session[6:8]}"
                    if rooms:
                        msg += f"- {time_str}: {', '.join(rooms[:10])}{'...' if len(rooms) > 10 else ''}\n"
                    else:
                        msg += f"- {time_str}: No rooms available.\n"
                return msg
            else:
                return f"Failed to query availability: {result.get('message', 'Unknown error')}"
        except Exception as e:
            return f"Error checking availability: {str(e)}"

    def _convert_location(self, location_name: Annotated[str, "Library location name in natural language (e.g., 'Chi Wah', 'Main Library')"]) -> str:
        """
        Convert natural language location name to location code.
        Args: 
            location_name: The library name mentioned by the user
        Returns:
            The location code if conversion successful, or an error message if not.
        """
        code, message = get_location_code(location_name)
        if code:
            self.collected_info["location"] = code
            return f" {message}"
        else:
            return f"{message}\n\nAvailable locations: {', '.join(LOCATION_NAMES)}"
    
    def _convert_room_type(self, room_type_name: Annotated[str, "Room type name in natural language (e.g., 'study room', 'discussion room')"]) -> str:
        """
        Convert natural language room type name to type code.
        Args:
            room_type_name: The room type name mentioned by the user
        Returns:
            The type code if conversion successful, or an error message if not.
        """
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
        """
        Collect and store the room numbers.
        Args: 
            rooms: The room numbers mentioned by the user
        Returns:
            Confirmation message of collected room numbers.
        """
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
        """
        Collect and store the booking date.
        Args:
            date: The booking date mentioned by the user in YYYYMMDD format
        Returns:
            Confirmation message of collected date or error message if format is invalid.
        """
        try:
            datetime.strptime(date, "%Y%m%d")
            self.collected_info["date"] = date
            return f"Date recorded: {date[:4]}-{date[4:6]}-{date[6:8]}"
        except ValueError:
            return "Invalid date format. Please use YYYYMMDD."
    
    def _collect_sessions(self, sessions: Annotated[str, "Time session codes (HHMMHHMM)"]) -> str:
        """
        Collect and store the time session codes.
        Args:
            sessions: The time sessions mentioned by the user in HHMMHHMM format
        Returns: 
            Confirmation message of collected sessions or error message if format is invalid.
        """
        session_list = [s.strip() for s in sessions.split(',')]
        self.collected_info["sessions"] = session_list
        return f"Time sessions recorded: {sessions}."
    
    def _check_information_complete(self) -> str:
        """
        Check if all required information has been collected.
        Returns:
            Message indicating missing information or that all information is complete.
        """
        missing = [k for k, v in self.collected_info.items() if v is None]
        if missing:
            return f"Missing information: {', '.join(missing)}."
        return "All required information has been collected. Ready to proceed with booking."
    
    def _execute_booking(self) -> str:
        """
        Execute the booking process directly in the database.
        Returns:
            A message indicating the result of the booking attempt.
        """
        if not self.user_id:
            return "Error: User identity not verified. Please log in again."
            
        missing = [k for k, v in self.collected_info.items() if v is None]
        if missing:
            return f"Cannot execute booking. Missing information: {', '.join(missing)}"
        
        try:
            booking_system = OptimizedBookingSystem(
                user_id=self.user_id,
                location=self.collected_info["location"],
                type_code=self.collected_info["type"],
                date_str=self.collected_info["date"],
                sessions=self.collected_info["sessions"]
            )
            
            result = booking_system.execute_booking(self.collected_info["rooms"])
            
            msg = ""
            if result["total_successful"] > 0:
                msg += f"Booking successful! {result['total_successful']}/{result['total_requested']} sessions booked.\n\n"
                for session, room in result["bookings"].items():
                    msg += f"- {room}: {session[:2]}:{session[2:4]}-{session[4:6]}:{session[6:8]}\n"
            
            if result["total_successful"] < result["total_requested"]:
                if msg:
                    msg += "\nSome sessions could not be booked:\n"
                else:
                    msg += "Booking failed for all requested sessions:\n"
                
                for session, errors in result.get("failures", {}).items():
                    time_str = f"{session[:2]}:{session[2:4]}-{session[4:6]}:{session[6:8]}"
                    msg += f"- {time_str}:\n  * " + "\n  * ".join(errors) + "\n"
            
            return msg
        except Exception as e:
            return f"A system error occurred during booking: {str(e)}. Please try again later or contact support."
    
    async def chat(self, user_message: str, thread=None) -> str:
        """
        Process a user message and return the agent's response.
        Args:
            user_message: The user's input message
            thread: Optional thread for maintaining conversation context
        Returns:
            The agent's response as a string
        """
        if self.agent is None:
            await self.initialize_agent()
        
        # make sure agent is initialized before proceeding
        assert self.agent is not None
        
        # If no thread provided, create a new one
        if thread is None:
            thread = self.agent.get_new_thread()
        
        response_text = ""
        async for chunk in self.agent.run_stream(user_message, thread=thread):
            if chunk.text:
                response_text += chunk.text
        
        return response_text
    
    async def start_conversation(self):
        """
        Start an interactive conversation session with the user.
        """
        if self.agent is None:
            await self.initialize_agent()
        
        # Ensure agent is initialized before starting conversation
        assert self.agent is not None
        
        thread = self.agent.get_new_thread()
        
        print("Booking Agent Initializing ....\n")
        
        # Initial greeting
        greeting = await self.chat("Hello, I need to book a study room.", thread=thread)
        print(f"Booking Agent: {greeting}\n")
        
        # Interactive loop
        while True:
            user_input = input("You: ").strip()
            if user_input.lower() in ['quit', 'exit', 'bye']:
                print("Booking Agent: Goodbye! Feel free to come back if you need to book again.")
                break
            
            if not user_input:
                continue
            
            response = await self.chat(user_input, thread=thread)
            print(f"Booking Agent: {response}\n")
    
    def reset(self):
        """Reset all collected information."""
        self.collected_info = {
            "location": None,
            "type": None,
            "rooms": None,
            "date": None,
            "sessions": None
        }
    
    def get_collected_info(self) -> Dict[str, Any]:
        """Get the currently collected information."""
        return self.collected_info.copy()


async def main():
    """Example usage of the BookingAgent."""
    # Use the token provided by user for testing
    github_token = ""  # <-- Replace with your GitHub token for testing
    agent = BookingAgent(github_token=github_token)
    await agent.start_conversation()


if __name__ == "__main__":
    asyncio.run(main())
