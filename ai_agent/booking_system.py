import sys
import os
import uuid
from datetime import datetime, time, date as date_obj
from typing import List, Dict, Any, Optional

# Put backend at the front of sys.path so local app package is resolved first.
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend'))
if backend_path not in sys.path:
    sys.path.insert(0, backend_path)

from app.core.database import SessionLocal
from app.services.reservation_service import ReservationService
from app.models import Facility, Library, Reservation, ReservationStatus, User
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
        
        # Mapping legacy HKU library codes to our local database library IDs. It should change when the db value change
        self.library_id_map = {
            "5": 1,  # Chi Wah Learning Commons
            "3": 2,  # Main Library
            "6": 3,  # Law Library
        }
        
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
            
            # Map legacy location code to library_id
            library_id = self.library_id_map.get(self.location_code)
            if not library_id:
                return {"success": False, "message": f"Unknown library code: {self.location_code}"}
                
            # Parse date
            try:
                booking_date = datetime.strptime(self.date_str, "%Y%m%d").date()
            except ValueError:
                return {"success": False, "message": "Invalid date format. Expected YYYYMMDD."}

            # Get all facilities in this library
            stmt = select(Facility).where(Facility.library_id == library_id)
            all_facilities = db.execute(stmt).scalars().all()
            
            available_by_session = {}
            
            for session_code in self.sessions:
                start_time, end_time = self._parse_session(session_code)
                available_rooms = []
                
                for facility in all_facilities:
                    # Check if this facility is already booked for this slot
                    overlap_stmt = select(Reservation).where(
                        Reservation.facility_id == facility.id,
                        Reservation.reservation_date == booking_date,
                        Reservation.start_time < end_time,
                        Reservation.end_time > start_time
                    ).limit(1)
                    
                    overlap = db.execute(overlap_stmt).scalar_one_or_none()
                    
                    if not overlap:
                        # Check operating hours
                        if start_time >= facility.open_time and end_time <= facility.close_time:
                            # Return original facility name (e.g., "Room 01")
                            available_rooms.append(facility.name)
                
                available_by_session[session_code] = available_rooms

            db.close()
            return {
                "success": True,
                "available_facilities": available_by_session,
                "date": self.date_str
            }
        except Exception as e:
            return {"success": False, "message": f"System error during availability check: {str(e)}"}

    def execute_booking(self, rooms: List[str]) -> Dict[str, Any]:
        """
        Execute the booking by creating records in the database.
        Args: 
            rooms: A list of room names corresponding to the requested sessions (in the same order).
        Return:
            a dictionary of results with detailed failure reasons.
        """
        db = SessionLocal()
        service = ReservationService(db)
        
        # Map legacy location code to library_id
        library_id = self.library_id_map.get(self.location_code)
        if not library_id:
            return {"success": False, "message": f"Unknown library code: {self.location_code}"}
            
        # Parse date
        try:
            booking_date = datetime.strptime(self.date_str, "%Y%m%d").date()
        except ValueError:
            return {"success": False, "message": "Invalid date format. Expected YYYYMMDD."}

        self.successful_bookings = {}
        failure_reasons = {}
        
        # Iterate through requested sessions
        for session_code in self.sessions:
            start_time, end_time = self._parse_session(session_code)
            session_success = False
            session_errors = []
            
            # Try rooms in order until one succeeds for this session
            for room_name in rooms:
                facility_id = self._get_facility_id(db, library_id, room_name)
                
                if not facility_id:
                    session_errors.append(f"{room_name}: Facility not found in this library.")
                    continue
                
                try:
                    # Perform validations using the backend service
                    facility = service.get_facility(facility_id)
                    service.enforce_lead_time(booking_date)
                    service.ensure_slot_within_facility_hours(facility, start_time, end_time)
                    service.ensure_slot_available(facility_id, booking_date, start_time, end_time)
                    service.ensure_user_has_no_overlap(self.user_id, booking_date, start_time, end_time)
                    
                    # If we reached here, the slot is available
                    reservation = Reservation(
                        user_id=self.user_id,
                        facility_id=facility_id,
                        reservation_date=booking_date,
                        start_time=start_time,
                        end_time=end_time,
                        status=ReservationStatus.confirmed,
                        notes="Booked via AI Agent"
                    )
                    
                    db.add(reservation)
                    db.commit()
                    db.refresh(reservation)
                    
                    self.successful_bookings[session_code] = room_name
                    session_success = True
                    break # Success for this session, move to next
                    
                except Exception as e:
                    # Extract error message (handle FastAPI HTTPException if needed)
                    err_msg = getattr(e, 'detail', str(e))
                    session_errors.append(f"{room_name}: {err_msg}")
                    db.rollback()
                    continue
            
            if not session_success:
                failure_reasons[session_code] = session_errors

        db.close()
        return {
            "success": len(self.successful_bookings) > 0,
            "bookings": self.successful_bookings,
            "failures": failure_reasons,
            "total_requested": len(self.sessions),
            "total_successful": len(self.successful_bookings)
        }