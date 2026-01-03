from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from jose import JWTError
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app import models  # noqa: F401
from app.core.config import settings
from app.core.database import Base, engine
from app.core import security
from app.routers import auth, facilities, libraries, occupancy_cv, reservations

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.app_name,
    version=settings.api_version,
    debug=settings.debug,
)

class TokenAuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        if request.method == "OPTIONS":
            return await call_next(request)
        if (
            path == f"/api/{settings.api_version}/auth/login"
            or path == f"/api/{settings.api_version}/auth/register"
            or path == "/health"
            or path in ("/docs", "/redoc", "/openapi.json")
        ):
            return await call_next(request)
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return JSONResponse(
                status_code=401,
                content={"detail": "Not authenticated"},
                headers={"WWW-Authenticate": "Bearer"},
            )
        token = auth_header.split(" ", 1)[1]
        try:
            subject = security.decode_access_token(token)
            request.state.user_subject = subject
        except JWTError:
            return JSONResponse(
                status_code=401,
                content={"detail": "Invalid or expired token"},
                headers={"WWW-Authenticate": "Bearer"},
            )
        return await call_next(request)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(TokenAuthMiddleware)

app.include_router(auth.router, prefix=f"/api/{settings.api_version}")
app.include_router(libraries.router, prefix=f"/api/{settings.api_version}")
app.include_router(facilities.router, prefix=f"/api/{settings.api_version}")
app.include_router(reservations.router, prefix=f"/api/{settings.api_version}")
app.include_router(occupancy_cv.router, prefix=f"/api/{settings.api_version}")


@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "ok", "app": settings.app_name}
