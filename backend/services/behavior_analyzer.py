"""
Riding behavior analyzer: detects dangerous events from fused sensor + CV data.
"""
from __future__ import annotations

import time
from collections import deque
from dataclasses import dataclass, field
from enum import Enum
from typing import Deque, Dict, List, Optional, Set

from services.sensor_fusion import FusedState, RidingContext
from services.object_detector import DetectionResult


class EventType(str, Enum):
    SPEEDING = "SPEEDING"
    HARD_BRAKING = "HARD_BRAKING"
    HARD_ACCELERATION = "HARD_ACCELERATION"
    ZIG_ZAG = "ZIG_ZAG"
    UNSAFE_DISTANCE = "UNSAFE_DISTANCE"
    UNSAFE_OVERTAKING = "UNSAFE_OVERTAKING"
    LANE_DEPARTURE = "LANE_DEPARTURE"
    CORNERING = "CORNERING"
    SMOOTH_RIDING = "SMOOTH_RIDING"


class Severity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


@dataclass
class RidingEvent:
    event_type: EventType
    severity: Severity
    timestamp: float
    description: str
    lat: float = 0.0
    lon: float = 0.0
    extra: dict = field(default_factory=dict)


# Speed limits by context (km/h)
_SPEED_LIMITS: Dict[RidingContext, float] = {
    RidingContext.CITY_TRAFFIC: 50.0,
    RidingContext.HIGHWAY: 100.0,
    RidingContext.EMPTY_ROAD: 80.0,
    RidingContext.TRAFFIC_JAM: 20.0,
    RidingContext.UNKNOWN: 60.0,
}

_SAFE_DISTANCE_M: Dict[RidingContext, float] = {
    RidingContext.CITY_TRAFFIC: 15.0,
    RidingContext.HIGHWAY: 50.0,
    RidingContext.EMPTY_ROAD: 30.0,
    RidingContext.TRAFFIC_JAM: 5.0,
    RidingContext.UNKNOWN: 20.0,
}


class BehaviorAnalyzer:
    """
    Analyses riding behavior frame-by-frame.

    Each call to ``analyze`` returns a list of newly detected events.
    Maintains a rolling window of recent events for aggression / accident scoring.
    """

    HARD_BRAKE_THRESHOLD = 7.0      # m/s² deceleration
    HARD_ACCEL_THRESHOLD = 6.0      # m/s² acceleration
    ZIG_ZAG_VARIANCE_THRESHOLD = 0.12   # rad/s² gyro Z variance
    LANE_DEV_THRESHOLD_PX = 80      # pixels from lane centre
    LEAN_ANGLE_WARN_DEG = 38.0      # cornering warning
    LEAN_ANGLE_CRITICAL_DEG = 50.0  # cornering critical
    OVERTAKE_YAW_THRESHOLD = 0.25   # rad/s
    OVERSPEED_MARGIN = 0.15         # 15% over limit triggers event

    COOLDOWN_S = 3.0  # minimum seconds between same event type

    def __init__(self) -> None:
        self._events: Deque[RidingEvent] = deque(maxlen=500)
        self._recent: Deque[RidingEvent] = deque(maxlen=100)
        self._last_event_ts: Dict[EventType, float] = {}
        self._gyro_z_buf: Deque[float] = deque(maxlen=30)
        self._lon_accel_buf: Deque[float] = deque(maxlen=10)
        self._overtake_lateral_buf: Deque[float] = deque(maxlen=20)

    def analyze(
        self,
        state: FusedState,
        detection: DetectionResult,
    ) -> List[RidingEvent]:
        new_events: List[RidingEvent] = []

        self._gyro_z_buf.append(state.angular_velocity)
        self._lon_accel_buf.append(state.longitudinal_accel)
        self._overtake_lateral_buf.append(state.lateral_accel)

        # 1. Speeding
        limit = _SPEED_LIMITS[state.context]
        if state.speed_kmh > limit * (1 + self.OVERSPEED_MARGIN):
            excess = state.speed_kmh - limit
            sev = Severity.HIGH if excess > 20 else Severity.MEDIUM
            ev = self._make_event(
                EventType.SPEEDING, sev, state,
                f"Speed {state.speed_kmh:.0f} km/h (limit {limit:.0f})",
                extra={"speed_kmh": state.speed_kmh, "limit_kmh": limit},
            )
            if ev:
                new_events.append(ev)

        # 2. Hard braking
        if state.longitudinal_accel < -self.HARD_BRAKE_THRESHOLD:
            sev = (Severity.CRITICAL
                   if state.longitudinal_accel < -12
                   else Severity.HIGH)
            ev = self._make_event(
                EventType.HARD_BRAKING, sev, state,
                f"Hard braking: {abs(state.longitudinal_accel):.1f} m/s²",
                extra={"decel_mss": state.longitudinal_accel},
            )
            if ev:
                new_events.append(ev)

        # 3. Hard acceleration
        if state.longitudinal_accel > self.HARD_ACCEL_THRESHOLD:
            ev = self._make_event(
                EventType.HARD_ACCELERATION, Severity.MEDIUM, state,
                f"Hard acceleration: {state.longitudinal_accel:.1f} m/s²",
            )
            if ev:
                new_events.append(ev)

        # 4. Zig-zag (gyro Z variance)
        if len(self._gyro_z_buf) >= 15:
            import numpy as np
            var = float(np.var(list(self._gyro_z_buf)))
            if var > self.ZIG_ZAG_VARIANCE_THRESHOLD:
                ev = self._make_event(
                    EventType.ZIG_ZAG, Severity.HIGH, state,
                    f"Zig-zag pattern detected (σ²={var:.3f})",
                    extra={"gyro_variance": var},
                )
                if ev:
                    new_events.append(ev)

        # 5. Unsafe following distance
        nearest = detection.nearest_vehicle_m
        safe_dist = _SAFE_DISTANCE_M[state.context]
        if nearest is not None and nearest < safe_dist and state.speed_kmh > 10:
            ratio = nearest / safe_dist
            sev = Severity.CRITICAL if ratio < 0.3 else (
                Severity.HIGH if ratio < 0.5 else Severity.MEDIUM
            )
            ev = self._make_event(
                EventType.UNSAFE_DISTANCE, sev, state,
                f"Only {nearest:.1f}m gap (safe={safe_dist:.0f}m at {state.speed_kmh:.0f}km/h)",
                extra={"distance_m": nearest, "safe_distance_m": safe_dist},
            )
            if ev:
                new_events.append(ev)

        # 6. Unsafe overtaking (lateral movement + oncoming vehicle)
        if detection.oncoming_vehicle and abs(state.lateral_accel) > 1.5:
            ev = self._make_event(
                EventType.UNSAFE_OVERTAKING, Severity.CRITICAL, state,
                "Overtaking with oncoming vehicle present",
                extra={"lateral_accel": state.lateral_accel},
            )
            if ev:
                new_events.append(ev)

        # 7. Lane departure
        if abs(detection.lane_deviation) > self.LANE_DEV_THRESHOLD_PX:
            ev = self._make_event(
                EventType.LANE_DEPARTURE, Severity.MEDIUM, state,
                f"Lane deviation: {detection.lane_deviation:.0f}px",
            )
            if ev:
                new_events.append(ev)

        # 8. Cornering stability
        if abs(state.lean_angle) > self.LEAN_ANGLE_CRITICAL_DEG:
            ev = self._make_event(
                EventType.CORNERING, Severity.HIGH, state,
                f"Extreme lean angle: {state.lean_angle:.1f}°",
                extra={"lean_angle": state.lean_angle},
            )
            if ev:
                new_events.append(ev)
        elif abs(state.lean_angle) > self.LEAN_ANGLE_WARN_DEG:
            ev = self._make_event(
                EventType.CORNERING, Severity.LOW, state,
                f"High lean angle: {state.lean_angle:.1f}°",
            )
            if ev:
                new_events.append(ev)

        for ev in new_events:
            self._events.append(ev)
            self._recent.append(ev)

        return new_events

    def _make_event(
        self,
        etype: EventType,
        severity: Severity,
        state: FusedState,
        description: str,
        extra: Optional[dict] = None,
    ) -> Optional[RidingEvent]:
        now = state.timestamp
        last = self._last_event_ts.get(etype, 0.0)
        if now - last < self.COOLDOWN_S:
            return None
        self._last_event_ts[etype] = now
        return RidingEvent(
            event_type=etype,
            severity=severity,
            timestamp=now,
            description=description,
            lat=state.lat,
            lon=state.lon,
            extra=extra or {},
        )

    def aggression_score(self) -> float:
        """0–100 composite aggression score based on recent behaviour."""
        recent_list = list(self._recent)
        if not recent_list:
            return 0.0
        weights = {
            EventType.HARD_BRAKING: 4,
            EventType.HARD_ACCELERATION: 3,
            EventType.UNSAFE_OVERTAKING: 6,
            EventType.ZIG_ZAG: 5,
            EventType.SPEEDING: 3,
            EventType.UNSAFE_DISTANCE: 4,
        }
        total = sum(weights.get(e.event_type, 1) for e in recent_list)
        return min(100.0, total * 2.5)

    def accident_probability(self, state: FusedState, nearest_m: Optional[float]) -> float:
        """Heuristic accident probability 0–1."""
        risk = 0.0
        limit = _SPEED_LIMITS[state.context]

        if state.speed_kmh > 0:
            speed_ratio = state.speed_kmh / (limit + 1)
            risk += min(0.3, (speed_ratio - 1.0) * 0.2)

        if nearest_m is not None:
            safe = _SAFE_DISTANCE_M[state.context]
            dist_ratio = nearest_m / (safe + 0.1)
            risk += max(0.0, (1.0 - dist_ratio) * 0.35)

        recent_severe = sum(
            1 for e in self._recent
            if e.severity in (Severity.HIGH, Severity.CRITICAL)
            and state.timestamp - e.timestamp < 30
        )
        risk += min(0.3, recent_severe * 0.05)

        return min(1.0, max(0.0, risk))

    def get_all_events(self) -> List[RidingEvent]:
        return list(self._events)

    def voice_alerts(self, new_events: List[RidingEvent]) -> List[str]:
        """Return voice alert strings for TTS."""
        mapping = {
            EventType.SPEEDING: "Slow down — speed limit exceeded",
            EventType.HARD_BRAKING: "Hard braking detected — maintain safe distance",
            EventType.ZIG_ZAG: "Zig-zag pattern detected — ride smoothly",
            EventType.UNSAFE_DISTANCE: "Vehicle too close — increase following distance",
            EventType.UNSAFE_OVERTAKING: "Unsafe overtaking — oncoming traffic present",
            EventType.LANE_DEPARTURE: "Lane departure detected",
            EventType.CORNERING: "Extreme lean angle — slow down",
        }
        seen: Set[EventType] = set()
        alerts = []
        for ev in new_events:
            if ev.event_type not in seen and ev.event_type in mapping:
                alerts.append(mapping[ev.event_type])
                seen.add(ev.event_type)
        return alerts
