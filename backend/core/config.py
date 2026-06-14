"""
Application configuration using Pydantic Settings.

All settings can be overridden via environment variables or a .env file.
"""
from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Central application settings loaded from environment variables or a .env file.

    Attributes:
        DATABASE_URL: Async-compatible SQLAlchemy connection string.
        SECRET_KEY: Secret used for JWT signing — must be replaced in production.
        ALGORITHM: JWT signing algorithm (e.g. "HS256").
        ACCESS_TOKEN_EXPIRE_MINUTES: Lifetime of issued access tokens in minutes.
        YOLO_MODEL_PATH: Filesystem path to the YOLO model weights file.
        CONFIDENCE_THRESHOLD: Minimum object-detection confidence score (0-1).
        MAX_SPEED_KMPH: Absolute maximum plausible speed in km/h for validation.
        SPEED_LIMIT_CITY: Urban speed limit in km/h used in behaviour scoring.
        SPEED_LIMIT_HIGHWAY: Highway speed limit in km/h used in behaviour scoring.
        VIDEO_FPS: Expected frames-per-second of processed video streams.
        FRAME_BUFFER_SIZE: Number of frames held in the in-memory ring buffer.
        WEBSOCKET_TIMEOUT: Seconds before an idle WebSocket connection is closed.
        UPLOAD_DIR: Directory where uploaded video/sensor files are stored.
        REPORTS_DIR: Directory where generated PDF/JSON reports are written.
        DATA_DIR: General-purpose data directory for auxiliary assets.
        DEBUG: Enables verbose SQLAlchemy echo and FastAPI debug mode when True.
    """

    DATABASE_URL: str = "sqlite+aiosqlite:///./learnhabit.db"
    SECRET_KEY: str = "your-secret-key-change-in-production-use-a-long-random-string"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    YOLO_MODEL_PATH: str = "yolov8n.pt"
    CONFIDENCE_THRESHOLD: float = 0.5
    MAX_SPEED_KMPH: float = 120.0
    SPEED_LIMIT_CITY: float = 50.0
    SPEED_LIMIT_HIGHWAY: float = 100.0

    VIDEO_FPS: int = 30
    FRAME_BUFFER_SIZE: int = 100
    WEBSOCKET_TIMEOUT: int = 300

    UPLOAD_DIR: str = "/app/uploads"
    REPORTS_DIR: str = "/app/reports"
    DATA_DIR: str = "/app/data"

    DEBUG: bool = False

    # CORS
    cors_origins: list[str] = ["*"]

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True)


# Module-level singleton — import this everywhere instead of re-instantiating Settings.
settings = Settings()
