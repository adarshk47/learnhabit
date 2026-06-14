"""
WebSocket endpoint for real-time bidirectional streaming.

Protocol:
  Client → Server: JSON (sensor data) or binary (JPEG frame)
  Server → Client: JSON (analysis results + alerts)
"""
from __future__ import annotations

import asyncio
import json
import logging
import time
import uuid
from typing import Dict, Set

import numpy as np
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from starlette.websockets import WebSocketState

from services.object_detector import ObjectDetector
from services.behavior_analyzer import BehaviorAnalyzer
from services.sensor_fusion import SensorFusionService, RawSensorData
from services.score_calculator import ScoreCalculator
from services.video_processor import VideoProcessor

logger = logging.getLogger(__name__)
router = APIRouter()

# Per-session state
_sessions: Dict[str, dict] = {}


class RideSession:
    def __init__(self, session_id: str) -> None:
        self.session_id = session_id
        self.detector = ObjectDetector()
        self.detector.load()
        self.fusion = SensorFusionService()
        self.behavior = BehaviorAnalyzer()
        self.scorer = ScoreCalculator()
        self.processor = VideoProcessor()
        self.scorer.start_ride()
        self._last_sensor: RawSensorData = RawSensorData(timestamp=time.time())
        self._frame_count = 0

    def process_sensor(self, data: dict) -> None:
        self._last_sensor = RawSensorData(
            timestamp=data.get("timestamp", time.time()),
            accel_x=data.get("accel_x", 0.0),
            accel_y=data.get("accel_y", 0.0),
            accel_z=data.get("accel_z", 9.81),
            gyro_x=data.get("gyro_x", 0.0),
            gyro_y=data.get("gyro_y", 0.0),
            gyro_z=data.get("gyro_z", 0.0),
            gps_lat=data.get("gps_lat", 0.0),
            gps_lon=data.get("gps_lon", 0.0),
            gps_speed_kmh=data.get("gps_speed_kmh", 0.0),
            gps_heading=data.get("gps_heading", 0.0),
        )

    def process_frame(self, raw_bytes: bytes) -> dict:
        self._frame_count += 1
        frame = self.processor.decode_jpeg(raw_bytes)
        if frame is None:
            return {"type": "error", "message": "bad_frame"}

        detection = self.detector.detect(frame)
        state = self.fusion.update(self._last_sensor, detection.vehicle_count)
        new_events = self.behavior.analyze(state, detection)
        smoothness = self.fusion.smoothness_score()
        scores = self.scorer.update(
            state, new_events, self.behavior, smoothness, detection.nearest_vehicle_m
        )
        alerts = self.behavior.voice_alerts(new_events)

        return {
            "type": "analysis_result",
            "timestamp": state.timestamp,
            "speed_kmh": state.speed_kmh,
            "lean_angle": state.lean_angle,
            "skill_score": round(scores.skill_score, 1),
            "danger_score": round(scores.danger_score, 1),
            "safety_rating": scores.safety_rating.value,
            "aggression_score": round(scores.aggression_score, 1),
            "accident_probability": round(scores.accident_probability, 3),
            "smoothness": round(scores.smoothness, 1),
            "detected_objects": detection.to_dict()["objects"],
            "traffic_density": round(detection.traffic_density, 2),
            "nearest_vehicle_m": detection.nearest_vehicle_m,
            "oncoming_vehicle": detection.oncoming_vehicle,
            "riding_context": state.context.value,
            "warnings": [e.event_type.value for e in new_events],
            "voice_alerts": alerts,
            "frame_count": self._frame_count,
        }


@router.websocket("/stream/{session_id}")
async def websocket_stream(websocket: WebSocket, session_id: str):
    await websocket.accept()
    session = RideSession(session_id)
    logger.info("WebSocket connected: session=%s", session_id)

    try:
        while True:
            try:
                message = await asyncio.wait_for(websocket.receive(), timeout=30.0)
            except asyncio.TimeoutError:
                await websocket.send_json({"type": "ping"})
                continue

            if message["type"] == "websocket.disconnect":
                break

            if "text" in message:
                # Sensor data packet
                try:
                    data = json.loads(message["text"])
                    if data.get("type") == "sensor_data":
                        session.process_sensor(data)
                        # Acknowledge sensor receipt
                        await websocket.send_json({"type": "sensor_ack"})
                except json.JSONDecodeError:
                    logger.warning("Invalid JSON from client")

            elif "bytes" in message and message["bytes"]:
                # Video frame — run AI and send back results
                result = session.process_frame(message["bytes"])
                if websocket.client_state == WebSocketState.CONNECTED:
                    await websocket.send_json(result)

    except WebSocketDisconnect:
        logger.info("WebSocket disconnected: session=%s", session_id)
    except Exception as exc:
        logger.exception("WebSocket error in session %s: %s", session_id, exc)
    finally:
        logger.info("Session %s ended after %d frames", session_id, session._frame_count)
