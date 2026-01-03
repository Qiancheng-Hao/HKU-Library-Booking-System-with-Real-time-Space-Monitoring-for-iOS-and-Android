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


class BookingAgent:
    """
    AI Agent that interacts with users to collect booking information
    and executes the booking process through OptimizedBookingSystem.
    
    The agent collects:
    - Location: Library location code
    - Type: Room type code
    - Room numbers: List of room IDs to attempt booking
    - Date: Booking date in YYYYMMDD format
    - Sessions: Time session codes
    """
    
    def __init__(self, github_token: str, model_id: str = "openai/o4-mini"):
        """
        Initialize the booking agent with GitHub model credentials.
        
        Args:
            github_token: GitHub personal access token for model access
            model_id: The model ID to use
        """
        self.github_token = github_token
        self.model_id = model_id
        self.agent = None
        self.collected_info = {
            "location": None,
            "type": None,
            "rooms": None,
            "date": None,
            "sessions": None,
        }
        self.username = None
        self.password = None
        
    async def initialize_agent(self):
        """Initialize the AI agent with GitHub model and tools."""
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
        - Examples of what users say:
            * "Chi Wah" / "CW" / "CWLC" 
            * "Main Library" / "Main"
            * "Law Library" / "Law"
            * "Medical Library" / "Medical"
            * "Music Library" / "Music"
        2. ROOM TYPE (facility type name):
        - User will say: "study room", "discussion room", "computer", etc.
        - You must: Call _convert_room_type() to convert name → code
        - Examples of what users say:
            * "study room" / "study"
            * "discussion room" / "discussion"
            * "computer" / "computer in LTC"
            * "single study room"
        3. ROOM NUMBERS (the actual room numbers they want):
        - User will say: "258" or "room 258" or "258 to 267" or "258, 259, 260"
        - You must: Call _collect_rooms() directly with the numbers
        - Note: These are ROOM NUMBERS visible on doors, NOT internal room IDs
        - Examples:
            * "258" → call _collect_rooms("258")
            * "258 to 267" → call _collect_rooms("258-267")
            * "258, 259, and 260" → call _collect_rooms("258,259,260")
        4. DATE (booking date):
        - User will say: "tomorrow", "December 28", "next Monday", etc.
        - You must: Convert to YYYYMMDD format and call _collect_date()
        - Today is 2025-12-27
        - Example: "tomorrow" → call _collect_date("20251228")
        5. TIME SESSIONS (time slots):
        - User will say: "8 to 9 AM", "morning", "8:00-9:00", etc.
        - You must: Convert to session code format and call _collect_sessions()
        - Format: "HHMM" + "HHMM" (start time + end time in 24-hour format)
        - Examples:
            * "8 to 9 AM" → call _collect_sessions("08000900")
            * "2 to 4 PM" → call _collect_sessions("14001600")
            * "9 AM to noon" → call _collect_sessions("09001200")
        6. CREDENTIALS (HKU login):
        - Username: HKU Portal UID or library card number
        - Password: Portal password or PIN
        - Call _collect_credentials(username, password)
        ═══════════════════════════════════════════════════════════════
        CRITICAL WORKFLOW - FOLLOW THESE STEPS EXACTLY:
        ═══════════════════════════════════════════════════════════════
        STEP 1: When user mentions a LOCATION NAME:
        → IMMEDIATELY call _convert_location(location_name)
        → Example: User says "Chi Wah" → _convert_location("Chi Wah")
        → The tool will automatically store the location code if successful
        → Do NOT just acknowledge - CALL THE TOOL
        STEP 2: When user mentions a ROOM TYPE NAME:
        → IMMEDIATELY call _convert_room_type(room_type_name)
        → Example: User says "study room" → _convert_room_type("study room")
        → The tool will automatically store the type code if successful
        → Do NOT just acknowledge - CALL THE TOOL
        STEP 3: When user mentions ROOM NUMBERS:
        → IMMEDIATELY call _collect_rooms(rooms)
        → Example: User says "258" → _collect_rooms("258")
        → Example: User says "258 to 267" → _collect_rooms("258-267")
        → Do NOT just acknowledge - CALL THE TOOL
        STEP 4: When user mentions DATE:
        → Convert to YYYYMMDD format
        → IMMEDIATELY call _collect_date(date)
        → Do NOT just acknowledge - CALL THE TOOL
        STEP 5: When user mentions TIME:
        → Convert to session code format (HHMMHHMM)
        → IMMEDIATELY call _collect_sessions(sessions)
        → Do NOT just acknowledge - CALL THE TOOL
        STEP 6: When user provides CREDENTIALS:
        → IMMEDIATELY call _collect_credentials(username, password)
        → Do NOT just acknowledge - CALL THE TOOL
        STEP 7: After collecting EACH piece of information:
        → IMMEDIATELY call _check_information_complete()
        → This verifies what's still missing
        STEP 8: When user says "book", "confirm", "proceed", "execute", or "yes":
        → If all information is complete:
            * IMMEDIATELY call _execute_booking()
            * Do NOT say "I will book" - ACTUALLY EXECUTE IT
        → If information is incomplete:
            * Tell user what's missing
            * Do NOT execute booking
        ═══════════════════════════════════════════════════════════════
        FORBIDDEN BEHAVIORS:
        ═══════════════════════════════════════════════════════════════
        Do NOT just acknowledge information without calling tools
        Do NOT say "I'll collect that" - CALL THE TOOL IMMEDIATELY
        Do NOT ask for location/type codes - users provide NAMES
        Do NOT call _collect_location() or _collect_type() directly
        → Use _convert_location() and _convert_room_type() instead
        Do NOT say "I will execute booking" - ACTUALLY EXECUTE IT
        ═══════════════════════════════════════════════════════════════
        AVAILABLE TOOLS:
        ═══════════════════════════════════════════════════════════════
        CONVERSION TOOLS (for names → codes):
        - _convert_location(location_name) - Convert location name to code
        - _convert_room_type(room_type_name) - Convert room type name to code
        COLLECTION TOOLS (for direct data):
        - _collect_rooms(rooms) - Store room numbers
        - _collect_date(date) - Store booking date (YYYYMMDD)
        - _collect_sessions(sessions) - Store time sessions (HHMMHHMM)
        - _collect_credentials(username, password) - Store login credentials
        STATUS TOOLS:
        - _check_information_complete() - Check what's missing
        - _execute_booking() - Execute the actual booking
        LEGACY TOOLS (DO NOT USE):
        - _collect_location() - DO NOT USE, use _convert_location() instead
        - _collect_type() - DO NOT USE, use _convert_room_type() instead
        ═══════════════════════════════════════════════════════════════
        REMEMBER:
        ═══════════════════════════════════════════════════════════════
        Your purpose is to EXECUTE bookings, not just chat about them.
        - Users provide NAMES (Chi Wah, study room)
        - You convert to CODES using conversion tools
        - You collect ROOM NUMBERS directly (258, 259, etc.)
        - You EXECUTE the booking when complete
        Always call the appropriate tools IMMEDIATELY when information is provided.
        """
        # Create agent with booking tools
        self.agent = ChatAgent(
            chat_client=chat_client,
            name="BookingAgent",
            instructions=instructions,
            tools=[
                self._convert_location,
                self._convert_room_type,
                self._collect_location,
                self._collect_type,
                self._collect_rooms,
                self._collect_date,
                self._collect_sessions,
                self._collect_credentials,
                self._check_information_complete,
                self._execute_booking
            ]
        )
        
    def _convert_location(self, location_name: Annotated[str, "Library location name in natural language (e.g., 'Chi Wah', 'Main Library')"]) -> str:
        """Convert natural language location name to location code using fuzzy matching.
        
        This tool automatically stores the location code if found.
        Supports various forms: 'Chi Wah', 'ChiWah', 'CW', 'CWLC', etc.
        """
        code, message = get_location_code(location_name)
        if code:
            self.collected_info["location"] = code
            return f" {message}"
        else:
            # Return suggestions
            return f"{message}\n\nAvailable locations: {', '.join(LOCATION_NAMES)}"
    
    def _convert_room_type(self, room_type_name: Annotated[str, "Room type name in natural language (e.g., 'study room', 'discussion room')"]) -> str:
        """Convert natural language room type name to type code using fuzzy matching.
        
        This tool automatically stores the type code if found.
        Requires location to be set first.
        """
        location_code = self.collected_info.get("location")
        if not location_code:
            return "Please specify location first before selecting room type."
        
        code, message = get_room_type_code(location_code, room_type_name)
        if code:
            self.collected_info["type"] = code
            # Also provide room range suggestions
            range_info = get_room_range_suggestions(location_code, code)
            return f" {message}\n{range_info}"
        else:
            return f"{message}\n\nPlease check available room types for the selected location."
    
    def _collect_location(self, location: str) -> str:
        """Collect and store the library location code."""
        self.collected_info["location"] = location
        return f"Location: {location} recorded."
    
    def _collect_type(self, room_type: str) -> str:
        """Collect and store the room type code."""
        self.collected_info["type"] = room_type
        return f"Room type: {room_type} recorded."
    
    def _collect_rooms(
        self,
        rooms: Annotated[str, "Room numbers as string: single number '258', comma-separated '258,259,260', or range '258-267'"]
    ) -> str:
        """Collect and store the room numbers to attempt booking."""
        # Parse room range or list
        room_list = []
        for part in rooms.split(','):
            part = part.strip()
            if '-' in part:
                # Handle range like "258-267"
                start, end = part.split('-')
                room_list.extend([str(r) for r in range(int(start), int(end) + 1)])
            else:
                room_list.append(part)
        
        self.collected_info["rooms"] = room_list
        return f"Room numbers recorded: {', '.join(room_list)}. The system will attempt to book these rooms in order."
    
    def _collect_date(
        self,
        date: Annotated[str, "Booking date in YYYYMMDD format (e.g., 20251220 for December 20, 2025)"]
    ) -> str:
        """Collect and store the booking date."""
        # Validate date format
        try:
            datetime.strptime(date, "%Y%m%d")
            self.collected_info["date"] = date
            # Format date for display
            year = date[:4]
            month = date[4:6]
            day = date[6:8]
            return f"Date recorded: {year}-{month}-{day}"
        except ValueError:
            return "Invalid date format. Please provide the date in YYYYMMDD format (e.g., 20251220)."
    
    def _collect_sessions(
        self,
        sessions: Annotated[str, "Time session code or comma-separated list (e.g., '14001500' for 2PM-3PM, or '14001500,15001600' for multiple sessions)"]
    ) -> str:
        """Collect and store the time session codes."""
        # Parse single session or multiple sessions
        session_list = [s.strip() for s in sessions.split(',')]
        self.collected_info["sessions"] = session_list
        
        # Format sessions for display
        formatted_sessions = []
        for session in session_list:
            if len(session) == 8:
                start_hour = session[:2]
                start_min = session[2:4]
                end_hour = session[4:6]
                end_min = session[6:8]
                formatted_sessions.append(f"{start_hour}:{start_min}-{end_hour}:{end_min}")
        
        return f"Time sessions recorded: {', '.join(formatted_sessions)}"
    
    def _collect_credentials(self, username: Annotated[str, "HKU portal UID or library card number"], password: Annotated[str, "Portal password or PIN"]) -> str:
        """Collect and store user credentials for booking."""
        self.collected_info["username"] = username
        self.collected_info["password"] = password
        return "Credentials recorded securely."
    
    def _check_information_complete(self) -> str:
        """Check if all required information has been collected."""
        missing = []
        for key, value in self.collected_info.items():
            if value is None:
                missing.append(key)
        if missing:
            return f"Missing information: {', '.join(missing)}. Please provide these details to proceed with booking."
        else:
            return "All required information has been collected. Ready to proceed with booking."
    
    def _execute_booking(self) -> str:
        """
        Execute the booking process using OptimizedBookingSystem.
        Returns a detailed result message.
        """
        # Check if all information is complete
        missing = [k for k, v in self.collected_info.items() if v is None]
        if missing:
            return f"Cannot execute booking. Missing information: {', '.join(missing)}"
        
        try:
            # Create booking system instance
            booking_system = OptimizedBookingSystem(
                username=self.collected_info["username"],
                password=self.collected_info["password"],
                location=self.collected_info["location"],
                type=self.collected_info["type"],
                date=self.collected_info["date"],
                sessions=self.collected_info["sessions"]
            )
            
            # Initialize drivers
            booking_system.initialize_multiple_drivers()
            
            # Pre-login all drivers
            login_threads = []
            for driver in booking_system.drivers:
                thread = threading.Thread(target=booking_system.pre_login, args=(driver,))
                login_threads.append(thread)
                thread.start()
            
            for thread in login_threads:
                thread.join()
                time.sleep(0.3)
            
            # Attempt concurrent booking
            booking_system.concurrent_booking_attempt(self.collected_info["rooms"])
            
            # Close all drivers
            booking_system.close_all_drivers()
            
            # Prepare result message
            if booking_system.successful_bookings:
                result_message = "Booking successful!\n\n"
                for session, room in booking_system.successful_bookings.items():
                    # Format session time
                    if len(session) == 8:
                        start_hour = session[:2]
                        start_min = session[2:4]
                        end_hour = session[4:6]
                        end_min = session[6:8]
                        time_str = f"{start_hour}:{start_min}-{end_hour}:{end_min}"
                    else:
                        time_str = session
                    
                    result_message += f"Room {room} booked for session {time_str}\n"
                
                if len(booking_system.successful_bookings) == len(self.collected_info["sessions"]):
                    result_message += "\n All requested sessions have been successfully booked!"
                else:
                    booked_sessions = set(booking_system.successful_bookings.keys())
                    requested_sessions = set(self.collected_info["sessions"])
                    failed_sessions = requested_sessions - booked_sessions
                    result_message += f"\n Some sessions could not be booked: {', '.join(failed_sessions)}"
                    result_message += "\nPossible reasons: rooms fully booked, network issues, or session unavailable."
                
                return result_message
            else:
                # Booking failed
                return """ Booking failed. No rooms could be booked.
                Possible reasons:
                1. All rooms are already fully booked for the requested time slots
                2. The date/time slots are not available for booking yet
                3. Invalid credentials
                4. Network connectivity issues
                5. The booking system is temporarily unavailable

                Please verify your information and try again, or choose a different date/time."""
        except Exception as e:
            return f" An error occurred during booking: {str(e)}\n\nPlease check your information and try again."
    
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
        This is a convenience method for command-line usage.
        """
        if self.agent is None:
            await self.initialize_agent()
        
        thread = self.agent.get_new_thread()
        
        print("Booking Agent: Hello! I'm here to help you book a study room at HKU Library.")
        print("Booking Agent: I'll need to collect some information from you. Let's get started!\n")
        
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
            "sessions": None,
            "username": None,
            "password": None
        }
    
    def get_collected_info(self) -> Dict[str, Any]:
        """Get the currently collected information."""
        return self.collected_info.copy()


async def main():
    """Example usage of the BookingAgent."""
    github_token = "hku"
    if github_token == "hku":
        raise ValueError("incorrect github token")
    agent = BookingAgent(github_token=github_token)
    await agent.start_conversation()


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
