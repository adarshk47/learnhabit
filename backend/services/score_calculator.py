"""
Scoring engine: calculates skill score, danger score, safety rating,
aggression score, and generates a trip summary.
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Tuple

from services.behavior_analyzer import BehaviorAnalyzer, EventType, RidingEvent, Severity
from services.sensor_fusion import FusedState, RidingContext


class SafetyRating(str, Enum):
    A = "A"
    B = "B"
    C = "C"
    D = "D"
    F = "F"


@dataclass
class LiveScores:
    skill_score: float = 100.0       # 0–100
    danger_score: float = 0.0        # 0–100
    safety_rating: SafetyRating = SafetyRating.A
    aggression_score: float = 0.0    # 0–100
    accident_probability: float = 0.0  # 0–1
    smoothness: float = 100.0        # 0–100

    def to_dict(self) -> dict:
        return {
            "skill_score": round(self.skill_score, 1),
            "danger_score": round(self.danger_score, 1),
            "safety_rating": self.safety_rating.value,
            "aggression_score": round(self.aggression_score, 1),
            "accident_probability": round(self.accident_probability, 3),
            "smoothness": round(self.smoothness, 1),
        }


@dataclass
class TripSummary:
    duration_s: float = 0.0
    distance_km: float = 0.0
    max_speed_kmh: float = 0.0
    avg_speed_kmh: float = 0.0
    skill_score: float = 0.0
    danger_score: float = 0.0
    safety_rating: str = "A"
    aggression_score: float = 0.0
    event_counts: Dict[str, int] = field(default_factory=dict)
    riding_context: str = "UNKNOWN"
    recommendations: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "duration_s": round(self.duration_s, 1),
            "distance_km": round(self.distance_km, 3),
            "max_speed_kmh": round(self.max_speed_kmh, 1),
            "avg_speed_kmh": round(self.avg_speed_kmh, 1),
            "skill_score": round(self.skill_score, 1),
            "danger_score": round(self.danger_score, 1),
            "safety_rating": self.safety_rating,
            "aggression_score": round(self.aggression_score, 1),
            "event_counts": self.event_counts,
            "riding_context": self.riding_context,
            "recommendations": self.recommendations,
        }


# Penalty per event type (deducted from 100)
_PENALTIES: Dict[EventType, float] = {
    EventType.SPEEDING: 4.0,
    EventType.HARD_BRAKING: 3.0,
    EventType.HARD_ACCELERATION: 2.0,
    EventType.ZIG_ZAG: 4.0,
    EventType.UNSAFE_DISTANCE: 5.0,
    EventType.UNSAFE_OVERTAKING: 6.0,
    EventType.LANE_DEPARTURE: 3.0,
    EventType.CORNERING: 2.0,
}

# Danger contribution per severity
_DANGER_WEIGHTS: Dict[Severity, float] = {
    Severity.LOW: 2.0,
    Severity.MEDIUM: 5.0,
    Severity.HIGH: 10.0,
    Severity.CRITICAL: 20.0,
}


class ScoreCalculator:
    def __init__(self) -> None:
        self._skill_score = 100.0
        self._danger_score = 0.0
        self._penalty_history: List[Tuple[float, float]] = []  # (timestamp, penalty)
        self._speeds: List[float] = []
        self._start_ts: float = 0.0
        self._prev_lat: float = 0.0
        self._prev_lon: float = 0.0
        self._distance_km: float = 0.0
        self._context_counts: Dict[RidingContext, int] = {c: 0 for c in RidingContext}

    def start_ride(self, lat: float = 0.0, lon: float = 0.0) -> None:
        self._start_ts = time.time()
        self._prev_lat = lat
        self._prev_lon = lon
        self._skill_score = 100.0
        self._danger_score = 0.0

    def update(
        self,
        state: FusedState,
        new_events: List[RidingEvent],
        behavior: BehaviorAnalyzer,
        smoothness: float,
        nearest_vehicle_m: Optional[float],
    ) -> LiveScores:
        now = state.timestamp

        # Track distance
        if self._prev_lat and state.lat:
            self._distance_km += self._haversine_km(
                self._prev_lat, self._prev_lon, state.lat, state.lon
            )
            self._prev_lat, self._prev_lon = state.lat, state.lon

        self._speeds.append(state.speed_kmh)
        self._context_counts[state.context] += 1

        # Apply penalties
        for ev in new_events:
            base_penalty = _PENALTIES.get(ev.event_type, 2.0)
            sev_mult = {
                Severity.LOW: 0.5,
                Severity.MEDIUM: 1.0,
                Severity.HIGH: 1.5,
                Severity.CRITICAL: 2.0,
            }.get(ev.severity, 1.0)
            penalty = base_penalty * sev_mult
            self._skill_score = max(0.0, self._skill_score - penalty)
            self._penalty_history.append((now, penalty))

        # Danger accumulates from severe events, decays slowly over time
        for ev in new_events:
            self._danger_score += _DANGER_WEIGHTS.get(ev.severity, 5.0)
        # Decay danger 0.5 per second
        elapsed = now - self._start_ts
        decay = min(self._danger_score, 0.5)
        self._danger_score = max(0.0, self._danger_score - decay)
        self._danger_score = min(100.0, self._danger_score)

        agg = behavior.aggression_score()
        acc_prob = behavior.accident_probability(state, nearest_vehicle_m)
        rating = self._calc_rating(self._skill_score)

        return LiveScores(
            skill_score=self._skill_score,
            danger_score=self._danger_score,
            safety_rating=rating,
            aggression_score=agg,
            accident_probability=acc_prob,
            smoothness=smoothness,
        )

    def generate_summary(self, behavior: BehaviorAnalyzer, context: RidingContext) -> TripSummary:
        events = behavior.get_all_events()
        duration = time.time() - self._start_ts if self._start_ts else 0
        avg_speed = sum(self._speeds) / len(self._speeds) if self._speeds else 0
        max_speed = max(self._speeds) if self._speeds else 0

        event_counts: Dict[str, int] = {}
        for ev in events:
            event_counts[ev.event_type.value] = event_counts.get(ev.event_type.value, 0) + 1

        recommendations = self._generate_recommendations(event_counts, avg_speed)

        return TripSummary(
            duration_s=duration,
            distance_km=self._distance_km,
            max_speed_kmh=max_speed,
            avg_speed_kmh=avg_speed,
            skill_score=self._skill_score,
            danger_score=self._danger_score,
            safety_rating=self._calc_rating(self._skill_score).value,
            aggression_score=behavior.aggression_score(),
            event_counts=event_counts,
            riding_context=context.value,
            recommendations=recommendations,
        )

    @staticmethod
    def _calc_rating(score: float) -> SafetyRating:
        if score >= 90:
            return SafetyRating.A
        if score >= 75:
            return SafetyRating.B
        if score >= 60:
            return SafetyRating.C
        if score >= 40:
            return SafetyRating.D
        return SafetyRating.F

    @staticmethod
    def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        import math
        R = 6371.0
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * \
            math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
        return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    @staticmethod
    def _generate_recommendations(
        event_counts: Dict[str, int], avg_speed: float
    ) -> List[str]:
        recs = []
        if event_counts.get("HARD_BRAKING", 0) > 2:
            recs.append("Maintain greater following distance to reduce hard braking incidents.")
        if event_counts.get("ZIG_ZAG", 0) > 1:
            recs.append("Focus on smoother lane positioning — avoid weaving through traffic.")
        if event_counts.get("SPEEDING", 0) > 3:
            recs.append("Consistently riding above speed limits — reduce speed for safety.")
        if event_counts.get("UNSAFE_OVERTAKING", 0) > 0:
            recs.append("Avoid overtaking near oncoming traffic — wait for a clear stretch.")
        if event_counts.get("UNSAFE_DISTANCE", 0) > 3:
            recs.append("Increase following distance, especially at higher speeds.")
        if not recs:
            recs.append("Excellent ride! Keep maintaining safe riding habits.")
        return recs
