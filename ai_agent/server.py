from fastmcp import FastMCP
from booking_system import OptimizedBookingSystem
from booking_agent import BookingAgent
import threading
import time
import asyncio
import uuid
from datetime import datetime, timedelta
from typing import Dict, Optional

mcp = FastMCP("HKU Library Booking Agent Server")

# Session management
# Structure: {session_id: {"agent": BookingAgent, "created_at": datetime, "last_activity": datetime}}
sessions: Dict[str, Dict] = {}
sessions_lock = threading.Lock()

# Session configuration
SESSION_TIMEOUT_MINUTES = 30  # Sessions expire after 30 minutes of inactivity
CLEANUP_INTERVAL_SECONDS = 300  # Run cleanup every 5 minutes


def cleanup_expired_sessions():
    """
    Background task to periodically clean up expired sessions.
    Removes sessions that have been inactive for longer than SESSION_TIMEOUT_MINUTES.
    """
    while True:
        time.sleep(CLEANUP_INTERVAL_SECONDS)
        
        with sessions_lock:
            current_time = datetime.now()
            expired_sessions = []
            
            for session_id, session_data in sessions.items():
                time_since_activity = current_time - session_data["last_activity"]
                if time_since_activity > timedelta(minutes=SESSION_TIMEOUT_MINUTES):
                    expired_sessions.append(session_id)
            
            for session_id in expired_sessions:
                del sessions[session_id]
                print(f"Cleaned up expired session: {session_id}")


# Start background cleanup thread
cleanup_thread = threading.Thread(target=cleanup_expired_sessions, daemon=True)
cleanup_thread.start()


def get_session(session_id: str) -> Optional[BookingAgent]:
    """
    Retrieve an agent instance for a given session ID and update last activity time.
    
    Args:
        session_id: Unique session identifier
    
    Returns:
        BookingAgent instance if session exists, None otherwise
    """
    with sessions_lock:
        if session_id in sessions:
            # Update last activity timestamp
            sessions[session_id]["last_activity"] = datetime.now()
            return sessions[session_id]["agent"]
        return None


@mcp.tool
def create_session(github_token: str, user_id: str) -> dict:
    """
    Create a new booking session for a specific user.
    Each session maintains isolated agent state for that user.
    
    Args:
        github_token: GitHub personal access token for model access
        user_id: The UUID of the user from the database
    
    Returns:
        Dictionary with session_id and status message
    """
    try:
        if not user_id:
            return {"status": "error", "message": "user_id is required"}
            
        # Generate unique session ID
        session_id = str(uuid.uuid4())
        
        # Create new agent instance for this session with the user_id
        agent = BookingAgent(github_token=github_token, user_id=user_id)
        
        # Store session
        with sessions_lock:
            sessions[session_id] = {
                "agent": agent,
                "created_at": datetime.now(),
                "last_activity": datetime.now(),
                "user_id": user_id
            }
        
        print(f"Created new session: {session_id} for user: {user_id}")
        
        return {
            "session_id": session_id,
            "status": "success",
            "message": f"Session created for user {user_id}. Ready for booking."
        }
        
    except Exception as e:
        return {
            "session_id": None,
            "status": "error",
            "message": f"Failed to create session: {str(e)}"
        }


@mcp.tool
async def chat_with_agent(session_id: str, message: str) -> dict:
    """
    Send a message to the booking agent within a specific session.
    The agent will collect booking information and execute bookings when ready.
    
    Args:
        session_id: Unique session identifier from create_session
        message: User's message to the agent
    
    Returns:
        Dictionary with agent's response and session status
    """
    try:
        agent = get_session(session_id)
        
        if agent is None:
            return {
                "status": "error",
                "message": "Invalid or expired session. Please create a new session using create_session."
            }
        
        # Chat with the agent
        response = await agent.chat(message)
        
        return {
            "status": "success",
            "response": response,
            "collected_info": agent.get_collected_info()
        }
        
    except Exception as e:
        return {
            "status": "error",
            "message": f"Error communicating with agent: {str(e)}"
        }


@mcp.tool
def reset_session(session_id: str) -> dict:
    """
    Reset the booking agent's collected information within a session.
    Clears all collected booking data but keeps the session active.
    
    Args:
        session_id: Unique session identifier
    
    Returns:
        Dictionary with status and message
    """
    try:
        agent = get_session(session_id)
        
        if agent is None:
            return {
                "status": "error",
                "message": "Invalid or expired session."
            }
        
        agent.reset()
        
        return {
            "status": "success",
            "message": "Session data has been reset. All collected information cleared."
        }
        
    except Exception as e:
        return {
            "status": "error",
            "message": f"Error resetting session: {str(e)}"
        }


@mcp.tool
def get_session_status(session_id: str) -> dict:
    """
    Get the current status and collected information from a session.
    
    Args:
        session_id: Unique session identifier
    
    Returns:
        Dictionary containing session metadata and collected booking information
    """
    try:
        with sessions_lock:
            if session_id not in sessions:
                return {
                    "status": "error",
                    "message": "Invalid or expired session."
                }
            
            session_data = sessions[session_id]
            agent = session_data["agent"]
            
            time_since_creation = datetime.now() - session_data["created_at"]
            time_since_activity = datetime.now() - session_data["last_activity"]
            
            return {
                "status": "success",
                "session_id": session_id,
                "user_id": session_data.get("user_id"),
                "created_at": session_data["created_at"].isoformat(),
                "last_activity": session_data["last_activity"].isoformat(),
                "session_age_minutes": int(time_since_creation.total_seconds() / 60),
                "idle_time_minutes": int(time_since_activity.total_seconds() / 60),
                "collected_info": agent.get_collected_info()
            }
            
    except Exception as e:
        return {
            "status": "error",
            "message": f"Error retrieving session status: {str(e)}"
        }


@mcp.tool
def end_session(session_id: str) -> dict:
    """
    Explicitly end a session and clean up resources.
    Use this when a user is done with booking to free up resources immediately.
    
    Args:
        session_id: Unique session identifier
    
    Returns:
        Dictionary with status and message
    """
    try:
        with sessions_lock:
            if session_id in sessions:
                user_id = sessions[session_id].get("user_id", "anonymous")
                del sessions[session_id]
                print(f"Ended session: {session_id} for user: {user_id}")
                
                return {
                    "status": "success",
                    "message": "Session ended successfully."
                }
            else:
                return {
                    "status": "error",
                    "message": "Session not found or already ended."
                }
                
    except Exception as e:
        return {
            "status": "error",
            "message": f"Error ending session: {str(e)}"
        }


@mcp.tool
def list_active_sessions() -> dict:
    """
    List all currently active sessions (for admin/monitoring purposes).
    
    Returns:
        Dictionary with count and list of active session IDs
    """
    try:
        with sessions_lock:
            active_sessions = []
            current_time = datetime.now()
            
            for session_id, session_data in sessions.items():
                time_since_activity = current_time - session_data["last_activity"]
                active_sessions.append({
                    "session_id": session_id,
                    "user_id": session_data.get("user_id"),
                    "created_at": session_data["created_at"].isoformat(),
                    "idle_minutes": int(time_since_activity.total_seconds() / 60)
                })
            
            return {
                "status": "success",
                "active_session_count": len(active_sessions),
                "sessions": active_sessions
            }
            
    except Exception as e:
        return {
            "status": "error",
            "message": f"Error listing sessions: {str(e)}"
        }
    
    
if __name__ == "__main__":
    print(f"Starting HKU Library Booking Agent Server...")
    print(f"Session timeout: {SESSION_TIMEOUT_MINUTES} minutes")
    print(f"Cleanup interval: {CLEANUP_INTERVAL_SECONDS} seconds")
    mcp.run(transport="http", port=8000)