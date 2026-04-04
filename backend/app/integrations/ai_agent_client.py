from __future__ import annotations

import logging
from typing import Any

import httpx

from app.core.config import settings
from app.schemas.ai import (
    AgentBaseResponse,
    AgentChatResponse,
    AgentCreateSessionResponse,
    AgentSessionStatusResponse,
)

logger = logging.getLogger(__name__)


class AIAgentClientError(Exception):
    pass


class AIAgentDisabledError(AIAgentClientError):
    pass


class AIAgentTimeoutError(AIAgentClientError):
    pass


class AIAgentUnavailableError(AIAgentClientError):
    pass


class AIAgentBadResponseError(AIAgentClientError):
    pass


class AIAgentClient:
    def __init__(self) -> None:
        self.base_url = settings.ai_agent_base_url.rstrip("/")
        self.timeout = settings.ai_agent_timeout_seconds
        self.shared_secret = settings.ai_agent_shared_secret

    def create_session(self, user_id: str) -> AgentCreateSessionResponse:
        return AgentCreateSessionResponse.model_validate(
            self._request(
                "POST",
                "/internal/v1/sessions",
                json={"user_id": user_id},
            )
        )

    def chat_with_agent(self, upstream_session_id: str, message: str) -> AgentChatResponse:
        return AgentChatResponse.model_validate(
            self._request(
                "POST",
                f"/internal/v1/sessions/{upstream_session_id}/messages",
                json={"message": message},
            )
        )

    def get_session_status(self, upstream_session_id: str) -> AgentSessionStatusResponse:
        return AgentSessionStatusResponse.model_validate(
            self._request("GET", f"/internal/v1/sessions/{upstream_session_id}")
        )

    def reset_session(self, upstream_session_id: str) -> AgentBaseResponse:
        return AgentBaseResponse.model_validate(
            self._request("POST", f"/internal/v1/sessions/{upstream_session_id}/reset")
        )

    def end_session(self, upstream_session_id: str) -> AgentBaseResponse:
        return AgentBaseResponse.model_validate(
            self._request("DELETE", f"/internal/v1/sessions/{upstream_session_id}")
        )

    def _request(self, method: str, path: str, json: dict[str, Any] | None = None) -> dict[str, Any]:
        if not settings.ai_agent_enabled:
            raise AIAgentDisabledError("AI service is disabled.")

        headers = {"Content-Type": "application/json"}
        if self.shared_secret:
            headers["X-Internal-Service-Token"] = self.shared_secret

        url = f"{self.base_url}{path}"
        logger.info("Calling ai_agent: method=%s path=%s", method, path)

        try:
            with httpx.Client(timeout=self.timeout) as client:
                response = client.request(method, url, json=json, headers=headers)
        except httpx.TimeoutException as exc:
            raise AIAgentTimeoutError("AI service timed out.") from exc
        except httpx.HTTPError as exc:
            raise AIAgentUnavailableError("AI service is unavailable.") from exc

        if response.status_code >= 500:
            raise AIAgentUnavailableError("AI service failed to process the request.")
        if response.status_code >= 400:
            detail = self._extract_detail(response)
            raise AIAgentBadResponseError(detail)

        try:
            payload = response.json()
        except ValueError as exc:
            raise AIAgentBadResponseError("AI service returned non-JSON payload.") from exc

        if payload.get("status") == "error":
            raise AIAgentBadResponseError(payload.get("message") or "AI service returned an error.")

        return payload

    @staticmethod
    def _extract_detail(response: httpx.Response) -> str:
        try:
            payload = response.json()
        except ValueError:
            return f"AI service returned HTTP {response.status_code}."
        if isinstance(payload, dict):
            return str(payload.get("detail") or payload.get("message") or f"AI service returned HTTP {response.status_code}.")
        return f"AI service returned HTTP {response.status_code}."
