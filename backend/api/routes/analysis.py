"""Analysis endpoints: per-frame processing and ride summaries."""
from __future__ import annotations

import base64
import time
from typing import Optional

import numpy as np
from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from models.ride import Ride
from services.object_detector import ObjectDetector
from services.behavior_analyzer import BehaviorAnalyzer
from services.sensor_fusion import SensorFusionService, RawSensorData
from services.score_calculator import ScoreCalculator
from services.video_processor import VideoProcessor
from schemas.analysis import (
    FrameAnalysisRequest,
    FrameAnalysisResponse,
    RideSummaryResponse,
)

router = APIRouter()

# Module-level singletons (one per server process)
_detector = ObjectDetector()
_detector.load()
_processor = VideoProcessor()
_fusion = SensorFusionService()
_behavior = BehaviorAnalyzer()
_scorer = ScoreCalculator()


@router.post("/frame", response_model=FrameAnalysisResponse)
async def analyze_frame(payload: FrameAnalysisRequest):
    """Analyze a single JPEG frame + sensor data and return AI results."""
    try:
        frame_bytes = base64.b64decode(payload.frame_b64)
        frame = _processor.decode_jpeg(frame_bytes)
        if frame is None:
            raise HTTPException(status_code=400, detail="Invalid frame data")

        raw = RawSensorData(
            timestamp=payload.timestamp or time.time(),
            accel_x=payload.accel_x,
            accel_y=payload.accel_y,
            accel_z=payload.accel_z,
            gyro_x=payload.gyro_x,
            gyro_y=payload.gyro_y,
            gyro_z=payload.gyro_z,
            gps_lat=payload.gps_lat,
            gps_lon=payload.gps_lon,
            gps_speed_kmh=payload.gps_speed_kmh,
            gps_heading=payload.gps_heading,
        )

        detection = _detector.detect(frame)
        state = _fusion.update(raw, detection.vehicle_count)
        new_events = _behavior.analyze(state, detection)
        smoothness = _fusion.smoothness_score()
        scores = _scorer.update(
            state, new_events, _behavior, smoothness, detection.nearest_vehicle_m
        )
        alerts = _behavior.voice_alerts(new_events)

        return FrameAnalysisResponse(
            speed_kmh=state.speed_kmh,
            skill_score=scores.skill_score,
            danger_score=scores.danger_score,
            safety_rating=scores.safety_rating.value,
            aggression_score=scores.aggression_score,
            accident_probability=scores.accident_probability,
            smoothness=scores.smoothness,
            detected_objects=detection.to_dict()["objects"],
            traffic_density=detection.traffic_density,
            lane_deviation=detection.lane_deviation,
            oncoming_vehicle=detection.oncoming_vehicle,
            riding_context=state.context.value,
            warnings=[e.event_type.value for e in new_events],
            voice_alerts=alerts,
            lean_angle=state.lean_angle,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/summary/{ride_id}", response_model=RideSummaryResponse)
async def get_ride_summary(ride_id: int, db: AsyncSession = Depends(get_db)):
    ride = await db.get(Ride, ride_id)
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

    summary = _scorer.generate_summary(_behavior, _fusion.current_state.context)

    return RideSummaryResponse(
        ride_id=ride_id,
        duration_s=summary.duration_s,
        distance_km=summary.distance_km,
        max_speed_kmh=summary.max_speed_kmh,
        avg_speed_kmh=summary.avg_speed_kmh,
        skill_score=summary.skill_score,
        danger_score=summary.danger_score,
        safety_rating=summary.safety_rating,
        aggression_score=summary.aggression_score,
        event_counts=summary.event_counts,
        riding_context=summary.riding_context,
        recommendations=summary.recommendations,
    )
