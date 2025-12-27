from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import models  # noqa: F401
from app.core.config import settings
from app.core.database import Base, engine
from app.routers import auth, facilities, libraries, reservations

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.app_name,
    version=settings.api_version,
    debug=settings.debug,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=f"/api/{settings.api_version}")
app.include_router(libraries.router, prefix=f"/api/{settings.api_version}")
app.include_router(facilities.router, prefix=f"/api/{settings.api_version}")
app.include_router(reservations.router, prefix=f"/api/{settings.api_version}")


@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "ok", "app": settings.app_name}

