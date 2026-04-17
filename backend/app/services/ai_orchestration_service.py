from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.integrations.ai_agent_client import AIAgentClient, AIAgentSessionExpiredError
from app.models import AISession
from app.schemas.ai import (
    AIChatRequest,
    AIChatResponse,
    AIResetRequest,
    AISessionCreateResponse,
    AISessionStatusResponse,
    AgentChatResponse,
    AgentSessionStatusResponse,
)


class AIOrchestrationService:
    def __init__(self, db: Session, client: AIAgentClient | None = None):
        self.db = db
        self.client = client or AIAgentClient()

    def create_session(self, user_id: uuid.UUID) -> AISessionCreateResponse:
        upstream = self.client.create_session(str(user_id))
        ai_session = AISession(
            ai_session_id=str(uuid.uuid4()),
            user_id=user_id,
            upstream_session_id=upstream.session_id or "",
            status="active",
            expires_at=upstream.expires_at or self._default_expiry(),
        )
        self.db.add(ai_session)
        self.db.commit()
        self.db.refresh(ai_session)
        return AISessionCreateResponse(
            aiSessionId=ai_session.ai_session_id,
            status="success",
            message=upstream.message or "AI session created.",
            createdAt=ai_session.created_at,
            expiresAt=ai_session.expires_at,
        )

    def chat(self, user_id: uuid.UUID, payload: AIChatRequest) -> AIChatResponse:
        session = self.get_session_record(user_id, payload.ai_session_id)
        try:
            upstream = self.client.chat_with_agent(session.upstream_session_id, payload.message)
        except AIAgentSessionExpiredError:
            upstream = self._recover_expired_upstream_session(session, user_id)
            return self._build_chat_response(upstream)

        session.last_message_summary = payload.message[:500]
        session.expires_at = self._default_expiry()
        self.db.add(session)
        self.db.commit()
        return self._build_chat_response(upstream)

    def get_status(self, user_id: uuid.UUID, ai_session_id: str) -> AISessionStatusResponse:
        session = self.get_session_record(user_id, ai_session_id)
        upstream = self.client.get_session_status(session.upstream_session_id)
        session.expires_at = upstream.expires_at or session.expires_at or self._default_expiry()
        self.db.add(session)
        self.db.commit()
        return AISessionStatusResponse(
            aiSessionId=session.ai_session_id,
            status=upstream.status,
            collectedInfo=upstream.collected_info,
            missingFields=upstream.missing_fields,
            isComplete=upstream.is_complete,
            readyForConfirmation=upstream.ready_for_confirmation,
            bookingPreview=upstream.booking_preview,
            suggestedOptions=upstream.suggested_options,
            warnings=upstream.warnings,
            createdAt=session.created_at,
            expiresAt=session.expires_at,
        )

    def reset(self, user_id: uuid.UUID, payload: AIResetRequest) -> AISessionStatusResponse:
        session = self.get_session_record(user_id, payload.ai_session_id)
        self.client.reset_session(session.upstream_session_id)
        session.last_intent_hash = None
        session.last_confirmed_intent_hash = None
        session.last_confirm_result = None
        session.status = "active"
        session.expires_at = self._default_expiry()
        self.db.add(session)
        self.db.commit()
        upstream = self.client.get_session_status(session.upstream_session_id)
        return AISessionStatusResponse(
            aiSessionId=session.ai_session_id,
            status=upstream.status,
            collectedInfo=upstream.collected_info,
            missingFields=upstream.missing_fields,
            isComplete=upstream.is_complete,
            readyForConfirmation=upstream.ready_for_confirmation,
            bookingPreview=upstream.booking_preview,
            suggestedOptions=upstream.suggested_options,
            warnings=upstream.warnings,
            createdAt=session.created_at,
            expiresAt=session.expires_at,
        )

    def end_session(self, user_id: uuid.UUID, ai_session_id: str) -> None:
        session = self.get_session_record(user_id, ai_session_id)
        self.client.end_session(session.upstream_session_id)
        session.status = "ended"
        self.db.add(session)
        self.db.commit()

    def get_session_record(self, user_id: uuid.UUID, ai_session_id: str) -> AISession:
        stmt = select(AISession).where(AISession.ai_session_id == ai_session_id)
        session = self.db.execute(stmt).scalar_one_or_none()
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="AI session not found.")
        if session.user_id != user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="AI session does not belong to the current user.")
        if session.status == "ended":
            raise HTTPException(status_code=status.HTTP_410_GONE, detail="AI session has already ended.")
        return session

    def _build_chat_response(self, upstream: AgentChatResponse) -> AIChatResponse:
        return AIChatResponse(
            reply=upstream.reply,
            collectedInfo=upstream.collected_info,
            missingFields=upstream.missing_fields,
            isComplete=upstream.is_complete,
            readyForConfirmation=upstream.ready_for_confirmation,
            bookingPreview=upstream.booking_preview,
            suggestedOptions=upstream.suggested_options,
            rawIntent=upstream.raw_intent,
            warnings=upstream.warnings,
        )

    def _recover_expired_upstream_session(
        self,
        session: AISession,
        user_id: uuid.UUID,
    ) -> AgentChatResponse:
        upstream = self.client.create_session(str(user_id))
        session.upstream_session_id = upstream.session_id or ""
        session.status = "active"
        session.expires_at = upstream.expires_at or self._default_expiry()
        session.last_message_summary = None
        session.last_intent_hash = None
        session.last_confirmed_intent_hash = None
        session.last_confirm_result = None
        self.db.add(session)
        self.db.commit()
        return AgentChatResponse(
            status="success",
            reply=(
                "I had to reconnect the AI booking assistant because the previous "
                "conversation expired. Please send your booking request again."
            ),
            warnings=[
                "The previous AI conversation was no longer available and has been restarted."
            ],
        )

    @staticmethod
    def _default_expiry() -> datetime:
        return datetime.now(timezone.utc) + timedelta(minutes=settings.ai_session_timeout_minutes)
