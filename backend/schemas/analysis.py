"""
Pydantic v2 schemas for real-time analysis requests and responses.

These cover the full data pipeline:
  SensorData → (fused with CV) → Detection + BehaviorFlags → RideScores → AnalysisResult
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Sensor input
# ---------------------------------------------------------------------------


class SensorData(BaseModel):
    """Raw sensor readings for a single analysis tick.

    All acceleration values are in m/s².
    All gyroscope values are in rad/s.
    GPS speed is in km/h.
    """

    accel_x: float = Field(default=0.0, description="Longitudinal acceleration (m/s²)")
    accel_y: float = Field(default=0.0, description="Lateral acceleration (m/s²)")
    accel_z: float = Field(default=9.81, description="Vertical acceleration (m/s²)")
    gyro_x: float = Field(default=0.0, description="Roll rate (rad/s)")
    gyro_y: float = Field(default=0.0, description="Pitch rate (rad/s)")
    gyro_z: float = Field(default=0.0, description="Yaw rate (rad/s) — steering signal")
    gps_lat: float = Field(default=0.0, ge=-90, le=90)
    gps_lon: float = Field(default=0.0, ge=-180, le=180)
    gps_speed: float = Field(default=0.0, ge=0, description="GPS speed (km/h)")
    gps_heading: float = Field(default=0.0, ge=0, le=360)
    gps_accuracy: float = Field(default=5.0, ge=0, description="GPS accuracy (m)")
    timestamp: float = Field(
        default=0.0, description="Unix epoch seconds when readings were taken"
    )


# ---------------------------------------------------------------------------
# CV / YOLO output
# ---------------------------------------------------------------------------


class Detection(BaseModel):
    """A single object detected by YOLO in a video frame."""

    class_name: str = Field(..., examples=["car", "motorcycle", "person"])
    confidence: float = Field(..., ge=0.0, le=1.0)
    bbox: List[float] = Field(
        ..., description="Bounding box [x1, y1, x2, y2] in pixels", min_length=4, max_length=4
    )
    track_id: Optional[int] = Field(None, description="YOLO tracking ID across frames")
    distance_m: Optional[float] = Field(
        None, ge=0, description="Estimated distance from rider in metres"
    )


# ---------------------------------------------------------------------------
# Behaviour flags
# ---------------------------------------------------------------------------


class BehaviorFlags(BaseModel):
    """Boolean and scalar flags describing rider behaviour for one analysis tick."""

    is_speeding: bool = False
    is_zigzag: bool = False
    hard_braking: bool = False
    dangerous_overtaking: bool = False
    unsafe_distance: bool = False
    rash_driving: bool = False
    cornering_risk: bool = False
    traffic_violation: bool = False
    aggression_level: float = Field(
        default=0.0, ge=0.0, le=10.0, description="Composite aggression score 0-10"
    )


# ---------------------------------------------------------------------------
# Scores
# ---------------------------------------------------------------------------


class RideScores(BaseModel):
    """Computed riding quality scores for a completed (or in-progress) ride."""

    skill_score: float = Field(
        default=100.0, ge=0.0, le=100.0, description="Overall riding skill 0-100"
    )
    danger_score: float = Field(
        default=0.0, ge=0.0, le=100.0, description="Cumulative danger level 0-100"
    )
    safety_rating: str = Field(
        default="Excellent",
        description="Human-readable safety label: Excellent/Good/Fair/Poor/Dangerous",
    )
    aggression_score: float = Field(
        default=0.0, ge=0.0, le=100.0, description="Aggression index 0-100"
    )
    accident_probability: float = Field(
        default=0.0, ge=0.0, le=1.0, description="Estimated accident probability 0-1"
    )
    confidence: float = Field(
        default=1.0, ge=0.0, le=1.0, description="Confidence in the computed scores"
    )


# ---------------------------------------------------------------------------
# Analysis request / response
# ---------------------------------------------------------------------------


class AnalysisRequest(BaseModel):
    """Payload for POST /analysis/frame — a base64-encoded frame + sensor readings."""

    ride_id: str
    frame_number: int = Field(default=0, ge=0)
    frame_b64: Optional[str] = Field(
        None, description="Base64-encoded JPEG/PNG frame image"
    )
    sensor_data: Optional[SensorData] = None


class AnalysisResult(BaseModel):
    """Full analysis result for a single processed frame."""

    frame_id: str
    frame_number: int
    timestamp: datetime
    detections: List[Detection] = []
    behavior_flags: BehaviorFlags = Field(default_factory=BehaviorFlags)
    scores: RideScores = Field(default_factory=RideScores)
    road_context: str = Field(
        default="unknown",
        description="Inferred context: empty_road/city/highway/heavy_traffic",
    )
    nearby_vehicles: int = Field(default=0, ge=0)
    speed_kmph: float = Field(default=0.0, ge=0)
    alerts: List[str] = Field(
        default_factory=list, description="Human-readable alert messages for this frame"
    )
    optical_flow_speed: float = Field(default=0.0, ge=0)


# ---------------------------------------------------------------------------
# WebSocket message envelopes
# ---------------------------------------------------------------------------


class WSIncoming(BaseModel):
    """Message format sent from a WebSocket client to the server."""

    type: str = Field(..., description="Message type: frame / sensor / ping / stop")
    ride_id: Optional[str] = None
    frame_number: Optional[int] = None
    frame_b64: Optional[str] = None
    sensor_data: Optional[SensorData] = None
    payload: Optional[Dict[str, Any]] = None


class WSOutgoing(BaseModel):
    """Message format sent from the server to a WebSocket client."""

    type: str
    ride_id: Optional[str] = None
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


# ---------------------------------------------------------------------------
# Trip summary (end-of-ride)
# ---------------------------------------------------------------------------


class TripSummary(BaseModel):
    """Complete post-ride summary returned by GET /analysis/{ride_id}/summary."""

    ride_id: str
    title: str
    duration_seconds: float
    distance_km: float
    road_context: str
    scores: RideScores
    event_counts: Dict[str, int] = Field(
        default_factory=dict,
        description="Counts of each event type e.g. {'hard_braking': 3, 'speeding': 5}",
    )
    improvement_tips: List[str] = []
    generated_at: datetime = Field(default_factory=datetime.utcnow)
