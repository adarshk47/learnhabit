"""
SQLAlchemy ORM models for Ride and RideEvent.

Ride represents a single bike trip session with all associated metadata
and computed scores. RideEvent captures individual incidents detected
during the trip (speeding, hard braking, etc.).
"""
from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum as PyEnum

from sqlalchemy import (
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from core.database import Base


class RideStatus(str, PyEnum):
    """Lifecycle states of a ride session."""

    pending = "pending"
    active = "active"
    completed = "completed"
    failed = "failed"


class Ride(Base):
    """Represents a single bike riding session.

    Stores trip metadata, video source, computed AI scores, and links
    to granular RideEvent and AnalysisFrame records.
    """

    __tablename__ = "rides"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    start_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=func.now()
    )
    end_time: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[str] = mapped_column(
        Enum(RideStatus), nullable=False, default=RideStatus.pending
    )
    distance_km: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    video_source: Mapped[str] = mapped_column(String(512), nullable=False, default="")

    # AI-computed scores (populated at end of ride)
    skill_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    danger_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    safety_rating: Mapped[str | None] = mapped_column(String(50), nullable=True)
    aggression_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    accident_probability: Mapped[float | None] = mapped_column(Float, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    events: Mapped[list["RideEvent"]] = relationship(
        "RideEvent", back_populates="ride", cascade="all, delete-orphan"
    )
    frames: Mapped[list["AnalysisFrame"]] = relationship(
        "AnalysisFrame", back_populates="ride", cascade="all, delete-orphan"
    )


class RideEvent(Base):
    """A single detected riding event (incident) within a ride session.

    Examples: speeding violation, hard braking, unsafe overtaking, etc.
    """

    __tablename__ = "ride_events"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    ride_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("rides.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
    severity: Mapped[str] = mapped_column(String(50), nullable=False, default="info")
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=func.now()
    )
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    speed_kmph: Mapped[float | None] = mapped_column(Float, nullable=True)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    metadata_json: Mapped[str] = mapped_column(
        Text, nullable=False, default="{}"
    )

    ride: Mapped["Ride"] = relationship("Ride", back_populates="events")
