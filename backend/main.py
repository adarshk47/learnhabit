"""
BikeAI Analyzer — FastAPI application entry point.

Mounts all API routers, configures CORS and GZip middleware, and manages
application lifecycle (database initialisation on startup, cleanup on shutdown).
"""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from core.config import settings
from core.database import init_db, close_db
from api.routes import rides, analysis, stream, reports

logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Async context manager for startup and shutdown events."""
    logger.info("Starting BikeAI Backend…")
    await init_db()
    logger.info("Database initialised.")
    yield
    logger.info("Shutting down BikeAI Backend…")
    await close_db()
    logger.info("Shutdown complete.")


app = FastAPI(
    title="BikeAI Analyzer API",
    description="AI-powered bike riding analysis system with real-time CV and sensor fusion.",
    version="1.0.0",
    lifespan=lifespan,
    debug=settings.DEBUG,
)

# ---------------------------------------------------------------------------
# Middleware
# ---------------------------------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)

# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------

app.include_router(rides.router, prefix="/api/v1/rides", tags=["rides"])
app.include_router(analysis.router, prefix="/api/v1/analysis", tags=["analysis"])
app.include_router(stream.router, prefix="/ws", tags=["stream"])
app.include_router(reports.router, prefix="/api/v1/reports", tags=["reports"])


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------


@app.get("/health", tags=["health"])
async def health_check() -> dict:
    """Simple liveness probe."""
    return {"status": "healthy", "version": "1.0.0"}
