"""
Pydantic v2 schemas for Ride and RideEvent resources.

These schemas are used for request validation (Create/Update) and
response serialisation.  All response schemas enable from_attributes=True
so they can be populated directly from SQLAlchemy ORM instances.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field

from models.ride import RideStatus


# ---------------------------------------------------------------------------
# RideEvent schemas
# ---------------------------------------------------------------------------


class RideEventCreate(BaseModel):
    """Payload for adding an event to a ride."""

    event_type: str = Field(..., max_length=100, examples=["hard_braking"])
    severity: str = Field(default="info", pattern="^(info|warning|critical)$")
    timestamp: Optional[datetime] = None
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    speed_kmph: Optional[float] = Field(None, ge=0)
    description: str = Field(default="")
    metadata_json: str = Field(default="{}")


class RideEventResponse(BaseModel):
    """Serialised representation of a RideEvent ORM instance."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    ride_id: str
    event_type: str
    severity: str
    timestamp: datetime
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    speed_kmph: Optional[float] = None
    description: str
    metadata_json: str


# ---------------------------------------------------------------------------
# Ride schemas
# ---------------------------------------------------------------------------


class RideCreate(BaseModel):
    """Payload for POST /rides — creates a new ride session."""

    user_id: str = Field(..., max_length=255, examples=["user-abc-123"])
    title: str = Field(..., max_length=255, examples=["Morning commute"])
    video_source: str = Field(default="", max_length=512)


class RideUpdate(BaseModel):
    """Payload for PATCH /rides/{ride_id} — partial update."""

    title: Optional[str] = Field(None, max_length=255)
    video_source: Optional[str] = Field(None, max_length=512)
    distance_km: Optional[float] = Field(None, ge=0)
    duration_seconds: Optional[int] = Field(None, ge=0)


class RideStatusUpdate(BaseModel):
    """Payload for PATCH /rides/{ride_id}/status."""

    status: RideStatus


class RideResponse(BaseModel):
    """Full ride representation returned by GET /rides endpoints."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    title: str
    start_time: datetime
    end_time: Optional[datetime] = None
    status: RideStatus
    distance_km: float
    duration_seconds: int
    video_source: str

    # AI scores (nullable until ride is completed)
    skill_score: Optional[float] = None
    danger_score: Optional[float] = None
    safety_rating: Optional[str] = None
    aggression_score: Optional[float] = None
    accident_probability: Optional[float] = None

    created_at: datetime
    updated_at: datetime


class RideListResponse(BaseModel):
    """Paginated list of rides."""

    total: int
    skip: int
    limit: int
    items: List[RideResponse]


class RideWithEventsResponse(RideResponse):
    """Ride response that embeds the associated events list."""

    events: List[RideEventResponse] = []
