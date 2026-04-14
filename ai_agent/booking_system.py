import sys
import os
import uuid
import re
from datetime import datetime, time, date as date_obj
from typing import List, Dict, Any, Optional
from dotenv import load_dotenv

# Put backend at the front of sys.path so local app package is resolved first.
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend'))
if backend_path not in sys.path:
    sys.path.insert(0, backend_path)

# Ensure backend database settings are loaded even when running from ai_agent/.
load_dotenv(os.path.join(backend_path, '.env'))

from app.core.database import SessionLocal
from app.models import Facility, Library, Reservation
from sqlalchemy import select

class OptimizedBookingSystem:
    """
    A Booking System that directly interacts with the backend database. 
    """
    def __init__(self, user_id: uuid.UUID, location: str | None, type_code: str | None, date_str: str | None, sessions: List[str] | None):
        """
        Initialize the booking system with database-ready information.
        Args:
            user_id: The UUID of the user making the booking
            location: The library code (mapped to library_id)
            type_code: The room type code
            date_str: Booking date in YYYYMMDD format
            sessions: List of time session codes (HHMMHHMM)
        """
        self.user_id = user_id
        self.location_code = location  # This is the HKU legacy code (e.g. "5" for Chi Wah)
        self.type_code = type_code
        self.date_str = date_str
        self.sessions = sessions if isinstance(sessions, list) else [sessions]
        self.successful_bookings = {}

    def _get_library_id_by_legacy_code(self, db, legacy_code: str | None) -> Optional[int]:
        """Resolve library_id dynamically by legacy_code instead of hard-coded IDs."""
        if not legacy_code:
            return None
        stmt = select(Library.id).where(Library.legacy_code == legacy_code).limit(1)
        return db.execute(stmt).scalar_one_or_none()
        
    def _parse_session(self, session_code: str) -> tuple[time, time]:
        """
        Convert HHMMHHMM session code to (start_time, end_time) objects.
        Args: 
            session_code: A string like "09001100" representing 9:00-11:00
        Returns:
            A tuple of (start_time, end_time) as time objects
        """
        # divide the string into start and end parts
        start_h, start_m = int(session_code[0:2]), int(session_code[2:4])
        end_h, end_m = int(session_code[4:6]), int(session_code[6:8])
        
        # Convert to time objects and return
        return time(hour=start_h, minute=start_m), time(hour=end_h, minute=end_m)

    @staticmethod
    def _format_time(value: time) -> str:
        return value.strftime("%H:%M")

    @staticmethod
    def _room_sort_key(room_name: str) -> tuple:
        """Natural sort key for names like 'Study Room 2', 'Study Room 10', 'Study Table R55'."""
        token = room_name.strip().split()[-1] if room_name.strip() else room_name.strip()
        match = re.match(r"^([A-Za-z]*)(\d+)$", token)
        if match:
            prefix, number = match.groups()
            return (0, prefix.lower(), int(number))
        return (1, token.lower(), room_name.lower())

    @staticmethod
    def _clip_to_facility_hours(
        requested_start: time,
        requested_end: time,
        open_time: time,
        close_time: time,
    ) -> tuple[time, time] | None:
        """Return overlapped slot with facility hours; None means no overlap."""
        adjusted_start = max(requested_start, open_time)
        adjusted_end = min(requested_end, close_time)
        if adjusted_start >= adjusted_end:
            return None
        return adjusted_start, adjusted_end

    def _get_facility_id(self, db, library_id: int, room_name: str) -> Optional[int]:
        """
        Find the database facility_id based on library and room name.
        Args: 
            db: Database session
            library_id: The ID of the library in our database
            room_name: The name of the room (e.g.,  "Discussion Room 01")
        Returns:
            The facility_id if found, None otherwise
        """
        # try multiple naming patterns to find the facility
        search_names = [room_name, f"Room {room_name}", f"Discussion Room {room_name}", f"Study Room {room_name}"]
        
        for name in search_names:
            # Query the database for a facility matching this library and name
            stmt = select(Facility).where(
                Facility.library_id == library_id,
                Facility.name == name
            )
            facility = db.execute(stmt).scalar_one_or_none()
            # If we found a matching facility, return its ID
            if facility:
                return facility.id
        # If no facility was found with any of the naming patterns, return None
        return None

    def get_available_facilities(self) -> Dict[str, Any]:
        """
        Query the database for all available facilities matching the criteria.
        Return: 
            A dictionary of available room names grouped by session.
        """
        try:
            db = SessionLocal()
            
            # Resolve library_id from legacy_code in database.
            library_id = self._get_library_id_by_legacy_code(db, self.location_code)
            if not library_id:
                return {"success": False, "message": f"Unknown library code: {self.location_code}"}
                
            # Parse date
            try:
                booking_date = datetime.strptime(self.date_str, "%Y%m%d").date()
            except ValueError:
                return {"success": False, "message": "Invalid date format. Expected YYYYMMDD."}

            # Restrict to facilities in selected library and selected type.
            stmt = select(Facility).where(
                Facility.library_id == library_id,
                Facility.facility_type_code == self.type_code,
                Facility.is_active.is_(True),
            )
            all_facilities = db.execute(stmt).scalars().all()
            
            available_by_session = {}
            session_diagnostics = {}
            
            for session_code in self.sessions:
                start_time, end_time = self._parse_session(session_code)
                available_rooms = []
                blocked_by_hours = 0
                blocked_by_booking = 0

                adjusted_time_range = None
                if all_facilities:
                    earliest_open = min(facility.open_time for facility in all_facilities)
                    latest_close = max(facility.close_time for facility in all_facilities)
                    overall_overlap = self._clip_to_facility_hours(start_time, end_time, earliest_open, latest_close)
                    if overall_overlap and overall_overlap != (start_time, end_time):
                        adjusted_time_range = (
                            f"{self._format_time(overall_overlap[0])}-{self._format_time(overall_overlap[1])}"
                        )
                
                for facility in all_facilities:
                    effective_slot = self._clip_to_facility_hours(
                        start_time,
                        end_time,
                        facility.open_time,
                        facility.close_time,
                    )
                    if effective_slot is None:
                        blocked_by_hours += 1
                        continue
                    effective_start, effective_end = effective_slot

                    # Check if this facility is already booked for this slot
                    overlap_stmt = select(Reservation).where(
                        Reservation.facility_id == facility.id,
                        Reservation.reservation_date == booking_date,
                        Reservation.start_time < effective_end,
                        Reservation.end_time > effective_start
                    ).limit(1)
                    
                    overlap = db.execute(overlap_stmt).scalar_one_or_none()
                    
                    if not overlap:
                        available_rooms.append(facility.name)
                    else:
                        blocked_by_booking += 1

                available_rooms.sort(key=self._room_sort_key)
                
                available_by_session[session_code] = available_rooms

                if not available_rooms:
                    if all_facilities and blocked_by_hours == len(all_facilities):
                        reason = "outside_opening_hours"
                        detail = "Requested time is outside facility opening hours."
                    elif all_facilities and blocked_by_booking == len(all_facilities):
                        reason = "fully_booked"
                        detail = "All matching facilities are already booked for this time slot."
                    else:
                        reason = "mixed_constraints"
                        detail = "No facilities match the requested slot due to opening-hour or booking constraints."
                else:
                    reason = "available"
                    detail = "Facilities are available."

                session_diagnostics[session_code] = {
                    "reason": reason,
                    "detail": detail,
                    "requested_time_range": f"{self._format_time(start_time)}-{self._format_time(end_time)}",
                    "adjusted_time_range": adjusted_time_range,
                    "total_candidates": len(all_facilities),
                    "blocked_by_hours": blocked_by_hours,
                    "blocked_by_booking": blocked_by_booking,
                    "available_count": len(available_rooms),
                }

            db.close()
            return {
                "success": True,
                "available_facilities": available_by_session,
                "session_diagnostics": session_diagnostics,
                "date": self.date_str
            }
        except Exception as e:
            return {"success": False, "message": f"System error during availability check: {str(e)}"}

