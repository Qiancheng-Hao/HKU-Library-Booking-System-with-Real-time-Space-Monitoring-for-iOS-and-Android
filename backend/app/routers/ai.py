import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.integrations.ai_agent_client import (
    AIAgentBadResponseError,
    AIAgentClientError,
    AIAgentDisabledError,
    AIAgentTimeoutError,
    AIAgentUnavailableError,
)
from app.schemas.ai import (
    AIChatRequest,
    AIChatResponse,
    AIConfirmRequest,
    AIConfirmResponse,
    AIResetRequest,
    AISessionCreateResponse,
    AISessionStatusResponse,
)
from app.services.ai_confirmation_service import AIConfirmationService
from app.services.ai_orchestration_service import AIOrchestrationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["AI"])


@router.post("/session", response_model=AISessionCreateResponse, status_code=status.HTTP_201_CREATED)
def create_ai_session(
    request: Request,
    db: Session = Depends(get_db),
) -> AISessionCreateResponse:
    user_id = _get_user_id(request)
    try:
        return AIOrchestrationService(db).create_session(user_id)
    except AIAgentClientError as exc:
        raise _map_ai_error(exc)


@router.post("/chat", response_model=AIChatResponse)
def chat_with_ai(
    payload: AIChatRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> AIChatResponse:
    user_id = _get_user_id(request)
    try:
        return AIOrchestrationService(db).chat(user_id, payload)
    except AIAgentClientError as exc:
        raise _map_ai_error(exc)


@router.post("/confirm", response_model=AIConfirmResponse)
def confirm_ai_booking(
    payload: AIConfirmRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> AIConfirmResponse:
    user_id = _get_user_id(request)
    try:
        return AIConfirmationService(db).confirm(user_id, payload)
    except AIAgentClientError as exc:
        raise _map_ai_error(exc)


@router.get("/session/{ai_session_id}", response_model=AISessionStatusResponse)
def get_ai_session_status(
    ai_session_id: str,
    request: Request,
    db: Session = Depends(get_db),
) -> AISessionStatusResponse:
    user_id = _get_user_id(request)
    try:
        return AIOrchestrationService(db).get_status(user_id, ai_session_id)
    except AIAgentClientError as exc:
        raise _map_ai_error(exc)


@router.post("/reset", response_model=AISessionStatusResponse)
def reset_ai_session(
    payload: AIResetRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> AISessionStatusResponse:
    user_id = _get_user_id(request)
    try:
        return AIOrchestrationService(db).reset(user_id, payload)
    except AIAgentClientError as exc:
        raise _map_ai_error(exc)


@router.delete("/session/{ai_session_id}", status_code=status.HTTP_204_NO_CONTENT)
def end_ai_session(
    ai_session_id: str,
    request: Request,
    db: Session = Depends(get_db),
) -> Response:
    user_id = _get_user_id(request)
    try:
        AIOrchestrationService(db).end_session(user_id, ai_session_id)
    except AIAgentClientError as exc:
        raise _map_ai_error(exc)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def _get_user_id(request: Request) -> uuid.UUID:
    try:
        return uuid.UUID(str(getattr(request.state, "user_subject")))
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


def _map_ai_error(exc: AIAgentClientError) -> HTTPException:
    logger.warning("AI endpoint error: %s", exc)
    if isinstance(exc, AIAgentDisabledError):
        return HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="AI service is disabled.")
    if isinstance(exc, AIAgentTimeoutError):
        return HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail="AI service timed out.")
    if isinstance(exc, AIAgentUnavailableError):
        return HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="AI service is temporarily unavailable.")
    if isinstance(exc, AIAgentBadResponseError):
        return HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc))
    return HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="AI service request failed.")
