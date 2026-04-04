from __future__ import annotations

import hashlib
import json
import re
import uuid
from datetime import datetime, time

from fastapi import HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.integrations.ai_agent_client import AIAgentClient
from app.models import Facility, Library, LibraryAlias
from app.schemas.ai import (
    AIConfirmRequest,
    AIConfirmResponse,
    AgentCollectedInfo,
    CreatedReservationItem,
    FailedReservationItem,
)
from app.services.ai_orchestration_service import AIOrchestrationService
from app.services.reservation_service import ReservationService


class AIConfirmationService:
    def __init__(self, db: Session, client: AIAgentClient | None = None):
        self.db = db
        self.client = client or AIAgentClient()
        self.orchestration = AIOrchestrationService(db=db, client=self.client)
        self.reservation_service = ReservationService(db)

    def confirm(self, user_id: uuid.UUID, payload: AIConfirmRequest) -> AIConfirmResponse:
        if not payload.confirm:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="confirm must be true.")

        session = self.orchestration.get_session_record(user_id, payload.ai_session_id)
        upstream = self.client.get_session_status(session.upstream_session_id)
        if not upstream.ready_for_confirmation:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="AI session is not ready for confirmation.",
            )

        collected_info = upstream.collected_info.model_copy(deep=True)
        if payload.selected_rooms:
            collected_info.rooms = payload.selected_rooms

        self._validate_collected_info(collected_info)
        intent_hash = self._build_intent_hash(user_id, collected_info)
        if (
            session.last_confirmed_intent_hash == intent_hash
            and session.last_confirm_result
        ):
            replay = AIConfirmResponse.model_validate(session.last_confirm_result)
            replay.idempotent_replay = True
            return replay

        session.last_intent_hash = intent_hash
        self.db.add(session)
        self.db.commit()

        library = self._resolve_library(collected_info)
        booking_date = datetime.strptime(collected_info.date or "", "%Y%m%d").date()
        created_reservations: list[CreatedReservationItem] = []
        failed_reservations: list[FailedReservationItem] = []

        for session_code in collected_info.sessions:
            start_time, end_time = self._parse_session_code(session_code)
            session_success = False
            failure_messages: list[str] = []

            for room_name in collected_info.rooms:
                try:
                    facility = self._resolve_facility(
                        library.id,
                        room_name,
                        collected_info.room_type_code,
                    )
                    reservation = self.reservation_service.create_confirmed_reservation(
                        user_id=user_id,
                        facility_id=facility.id,
                        reservation_date=booking_date,
                        start_time=start_time,
                        end_time=end_time,
                        notes="Booked via AI confirmation",
                    )
                    created_reservations.append(
                        CreatedReservationItem(
                            reservationId=str(reservation.id),
                            facilityId=facility.id,
                            facilityName=facility.name,
                            reservationDate=reservation.reservation_date.isoformat(),
                            startTime=reservation.start_time.strftime("%H:%M"),
                            endTime=reservation.end_time.strftime("%H:%M"),
                        )
                    )
                    session_success = True
                    break
                except HTTPException as exc:
                    detail = exc.detail if isinstance(exc.detail, str) else str(exc.detail)
                    failure_messages.append(f"{room_name}: {detail}")
                    self.db.rollback()
                except Exception as exc:
                    failure_messages.append(f"{room_name}: {exc}")
                    self.db.rollback()

            if not session_success:
                failed_reservations.append(
                    FailedReservationItem(
                        session=self._format_session_code(session_code),
                        room=",".join(collected_info.rooms),
                        reason="; ".join(failure_messages) or "Unable to create reservation.",
                    )
                )

        response = AIConfirmResponse(
            success=bool(created_reservations),
            createdReservations=created_reservations,
            failedReservations=failed_reservations,
            summary=self._build_summary(created_reservations, failed_reservations),
            usedCollectedInfo=collected_info,
            idempotentReplay=False,
        )

        session.last_confirm_result = response.model_dump(by_alias=True)
        if created_reservations:
            session.last_confirmed_intent_hash = intent_hash
            session.status = "confirmed"
        self.db.add(session)
        self.db.commit()
        return response

    @staticmethod
    def _parse_session_code(session_code: str) -> tuple[time, time]:
        if len(session_code) != 8 or not session_code.isdigit():
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid session code: {session_code}")
        return (
            time(hour=int(session_code[0:2]), minute=int(session_code[2:4])),
            time(hour=int(session_code[4:6]), minute=int(session_code[6:8])),
        )

    @staticmethod
    def _format_session_code(session_code: str) -> str:
        return f"{session_code[0:2]}:{session_code[2:4]}-{session_code[4:6]}:{session_code[6:8]}"

    @staticmethod
    def _build_intent_hash(user_id: uuid.UUID, collected_info: AgentCollectedInfo) -> str:
        payload = {
            "user_id": str(user_id),
            "location": collected_info.location,
            "location_code": collected_info.location_code,
            "room_type": collected_info.room_type,
            "room_type_code": collected_info.room_type_code,
            "date": collected_info.date,
            "sessions": collected_info.sessions,
            "rooms": collected_info.rooms,
        }
        return hashlib.sha256(json.dumps(payload, sort_keys=True).encode("utf-8")).hexdigest()

    @staticmethod
    def _build_summary(
        created_reservations: list[CreatedReservationItem],
        failed_reservations: list[FailedReservationItem],
    ) -> str:
        if created_reservations and not failed_reservations:
            return f"Successfully created {len(created_reservations)} reservation(s)."
        if created_reservations and failed_reservations:
            return (
                f"Created {len(created_reservations)} reservation(s) with "
                f"{len(failed_reservations)} failed session(s)."
            )
        return f"No reservations were created. {len(failed_reservations)} session(s) failed."

    def _resolve_library(self, collected_info: AgentCollectedInfo) -> Library:
        if not (collected_info.location or collected_info.location_code):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing library information.")
        stmt = select(Library)
        if collected_info.location_code:
            mapped_name = self._library_name_from_code(collected_info.location_code)
            conditions = [
                Library.legacy_code == collected_info.location_code,
            ]
            if mapped_name:
                conditions.append(func.lower(Library.name) == mapped_name.lower())
            stmt = stmt.where(or_(*conditions))
        elif collected_info.location:
            normalized_location = collected_info.location.strip().lower()
            stmt = stmt.outerjoin(LibraryAlias, LibraryAlias.library_id == Library.id).where(
                or_(
                    func.lower(Library.name) == normalized_location,
                    func.lower(LibraryAlias.alias) == normalized_location,
                )
            )
        library = self.db.execute(stmt).scalars().first()
        if not library:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Library not found.")
        return library

    def _resolve_facility(
        self,
        library_id: int,
        room_name: str,
        room_type_code: str | None,
    ) -> Facility:
        candidates = [
            room_name.strip(),
            f"Room {room_name.strip()}",
            f"Discussion Room {room_name.strip()}",
            f"Study Room {room_name.strip()}",
        ]
        stmt = select(Facility).where(
            Facility.library_id == library_id,
            Facility.is_active.is_(True),
            Facility.is_bookable.is_(True),
        )
        if room_type_code:
            stmt = stmt.where(Facility.facility_type_code == room_type_code)

        normalized_room_name = self._normalize_room_no(room_name)
        if normalized_room_name.isdigit():
            stmt = stmt.where(
                (Facility.room_no == normalized_room_name)
                | (func.lower(Facility.name).in_([candidate.lower() for candidate in candidates]))
            )
        else:
            stmt = stmt.where(func.lower(Facility.name).in_([candidate.lower() for candidate in candidates]))
        facility = self.db.execute(stmt).scalars().first()
        if not facility:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Facility {room_name} not found in selected library.")
        return facility

    @staticmethod
    def _library_name_from_code(location_code: str | None) -> str | None:
        mapping = {
            "5": "Chi Wah Learning Commons",
            "3": "Main Library",
            "6": "Law Library",
        }
        if not location_code:
            return None
        return mapping.get(location_code)

    @staticmethod
    def _validate_collected_info(collected_info: AgentCollectedInfo) -> None:
        missing = []
        if not (collected_info.location or collected_info.location_code):
            missing.append("location")
        if not collected_info.room_type_code:
            missing.append("room_type")
        if not collected_info.date:
            missing.append("date")
        if not collected_info.sessions:
            missing.append("sessions")
        if not collected_info.rooms:
            missing.append("rooms")
        if missing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Collected information is incomplete: {', '.join(missing)}.",
            )

    @staticmethod
    def _normalize_room_no(raw_room_name: str) -> str:
        normalized = raw_room_name.strip()
        match = re.search(r"(\d+)$", normalized)
        if match:
            return match.group(1)
        return normalized
