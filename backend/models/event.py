"""
SQLAlchemy ORM model for AnalysisFrame.

Each AnalysisFrame captures the full state of one processed video frame,
including raw detections, computed behaviour flags, sensor readings, and
live scores. This provides a frame-by-frame audit trail for a ride.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from core.database import Base

# Import Ride so SQLAlchemy registers the relationship target before this module
# is used (avoids mapper configuration errors on startup).
from models.ride import Ride  # noqa: F401


class AnalysisFrame(Base):
    """Stores per-frame analysis results for a ride.

    Attributes:
        ride_id: FK to the parent Ride.
        frame_number: Sequential index of the frame within the ride stream.
        timestamp: Wall-clock time when the frame was captured / processed.
        detections_json: JSON array of YOLO detection dicts for this frame.
        behavior_flags_json: JSON dict of BehaviourFlags for this frame.
        sensor_data_json: JSON dict of raw sensor readings attached to this frame.
        scores_json: JSON dict of live scores (skill, danger, etc.) at this frame.
        optical_flow_speed: Speed estimate derived from optical flow (km/h).
    """

    __tablename__ = "analysis_frames"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    ride_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("rides.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    frame_number: Mapped[int] = mapped_column(Integer, nullable=False)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=func.now()
    )
    detections_json: Mapped[str] = mapped_column(Text, nullable=False, default="[]")
    behavior_flags_json: Mapped[str] = mapped_column(
        Text, nullable=False, default="{}"
    )
    sensor_data_json: Mapped[str] = mapped_column(Text, nullable=False, default="{}")
    scores_json: Mapped[str] = mapped_column(Text, nullable=False, default="{}")
    optical_flow_speed: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0
    )

    ride: Mapped["Ride"] = relationship("Ride", back_populates="frames")
