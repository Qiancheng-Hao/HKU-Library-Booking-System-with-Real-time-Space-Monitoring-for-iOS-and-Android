from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AIModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True)


class AgentCollectedInfo(AIModel):
    location: str | None = None
    location_code: str | None = None
    room_type: str | None = None
    room_type_code: str | None = None
    date: str | None = None
    sessions: list[str] = Field(default_factory=list)
    rooms: list[str] = Field(default_factory=list)


class AgentBookingPreview(AIModel):
    library: str | None = None
    date: str | None = None
    time_ranges: list[str] = Field(default_factory=list)
    candidate_rooms: list[str] = Field(default_factory=list)


class AgentSuggestedOptions(AIModel):
    locations: list[str] = Field(default_factory=list)
    room_types: list[str] = Field(default_factory=list)
    rooms: list[str] = Field(default_factory=list)


class AgentBaseResponse(AIModel):
    status: str
    message: str | None = None


class AgentCreateSessionResponse(AgentBaseResponse):
    session_id: str | None = None
    created_at: datetime | None = None
    expires_at: datetime | None = None


class AgentChatResponse(AgentBaseResponse):
    reply: str = ""
    collected_info: AgentCollectedInfo = Field(default_factory=AgentCollectedInfo)
    missing_fields: list[str] = Field(default_factory=list)
    is_complete: bool = False
    ready_for_confirmation: bool = False
    booking_preview: AgentBookingPreview = Field(default_factory=AgentBookingPreview)
    suggested_options: AgentSuggestedOptions = Field(default_factory=AgentSuggestedOptions)
    warnings: list[str] = Field(default_factory=list)
    raw_intent: dict | None = None


class AgentSessionStatusResponse(AgentChatResponse):
    session_id: str | None = None
    user_id: str | None = None
    created_at: datetime | None = None
    last_activity: datetime | None = None
    expires_at: datetime | None = None


class AISessionCreateResponse(AIModel):
    ai_session_id: str = Field(alias="aiSessionId")
    status: str
    message: str
    created_at: datetime | None = Field(default=None, alias="createdAt")
    expires_at: datetime | None = Field(default=None, alias="expiresAt")


class AIChatRequest(AIModel):
    ai_session_id: str = Field(alias="aiSessionId", min_length=1)
    message: str = Field(min_length=1)


class AIChatResponse(AIModel):
    reply: str
    collected_info: AgentCollectedInfo = Field(alias="collectedInfo")
    missing_fields: list[str] = Field(alias="missingFields")
    is_complete: bool = Field(alias="isComplete")
    ready_for_confirmation: bool = Field(alias="readyForConfirmation")
    booking_preview: AgentBookingPreview = Field(alias="bookingPreview")
    suggested_options: AgentSuggestedOptions = Field(alias="suggestedOptions")
    raw_intent: dict | None = Field(default=None, alias="rawIntent")
    warnings: list[str] = Field(default_factory=list)


class AISessionStatusResponse(AIModel):
    ai_session_id: str = Field(alias="aiSessionId")
    status: str
    collected_info: AgentCollectedInfo = Field(alias="collectedInfo")
    missing_fields: list[str] = Field(alias="missingFields")
    is_complete: bool = Field(alias="isComplete")
    ready_for_confirmation: bool = Field(alias="readyForConfirmation")
    booking_preview: AgentBookingPreview = Field(alias="bookingPreview")
    suggested_options: AgentSuggestedOptions = Field(alias="suggestedOptions")
    warnings: list[str] = Field(default_factory=list)
    created_at: datetime | None = Field(default=None, alias="createdAt")
    expires_at: datetime | None = Field(default=None, alias="expiresAt")


class AIResetRequest(AIModel):
    ai_session_id: str = Field(alias="aiSessionId", min_length=1)


class AIConfirmRequest(AIModel):
    ai_session_id: str = Field(alias="aiSessionId", min_length=1)
    selected_rooms: list[str] = Field(default_factory=list, alias="selectedRooms")
    confirm: bool = True


class CreatedReservationItem(AIModel):
    reservation_id: str = Field(alias="reservationId")
    facility_id: int = Field(alias="facilityId")
    facility_name: str = Field(alias="facilityName")
    reservation_date: str = Field(alias="reservationDate")
    start_time: str = Field(alias="startTime")
    end_time: str = Field(alias="endTime")


class FailedReservationItem(AIModel):
    session: str
    room: str
    reason: str


class AIConfirmResponse(AIModel):
    success: bool
    created_reservations: list[CreatedReservationItem] = Field(alias="createdReservations")
    failed_reservations: list[FailedReservationItem] = Field(alias="failedReservations")
    summary: str
    used_collected_info: AgentCollectedInfo = Field(alias="usedCollectedInfo")
    idempotent_replay: bool = Field(default=False, alias="idempotentReplay")
