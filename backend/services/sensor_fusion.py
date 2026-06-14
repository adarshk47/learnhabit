"""
Sensor fusion: fuses accelerometer, gyroscope, and GPS data
using a Kalman filter to produce smooth, accurate riding metrics.
"""
from __future__ import annotations

import math
import time
from collections import deque
from dataclasses import dataclass, field
from enum import Enum
from typing import Deque, Optional, Tuple

import numpy as np


class RidingContext(str, Enum):
    CITY_TRAFFIC = "CITY_TRAFFIC"
    HIGHWAY = "HIGHWAY"
    EMPTY_ROAD = "EMPTY_ROAD"
    TRAFFIC_JAM = "TRAFFIC_JAM"
    UNKNOWN = "UNKNOWN"


@dataclass
class RawSensorData:
    timestamp: float
    accel_x: float = 0.0   # m/s² forward/back
    accel_y: float = 0.0   # m/s² left/right
    accel_z: float = 9.81  # m/s² up/down (gravity)
    gyro_x: float = 0.0    # rad/s roll
    gyro_y: float = 0.0    # rad/s pitch
    gyro_z: float = 0.0    # rad/s yaw (steering)
    gps_lat: float = 0.0
    gps_lon: float = 0.0
    gps_speed_kmh: float = 0.0
    gps_heading: float = 0.0
    gps_accuracy_m: float = 5.0


@dataclass
class FusedState:
    timestamp: float = 0.0
    speed_kmh: float = 0.0
    lateral_accel: float = 0.0
    longitudinal_accel: float = 0.0
    angular_velocity: float = 0.0  # yaw rate rad/s
    lean_angle: float = 0.0        # degrees
    heading: float = 0.0
    lat: float = 0.0
    lon: float = 0.0
    jerk: float = 0.0              # rate of change of acceleration
    context: RidingContext = RidingContext.UNKNOWN


class SimpleKalman1D:
    """1-D Kalman filter for smoothing noisy sensor readings."""

    def __init__(self, process_noise: float = 0.01, measurement_noise: float = 0.1):
        self.q = process_noise
        self.r = measurement_noise
        self.x = 0.0   # state estimate
        self.p = 1.0   # estimate uncertainty

    def update(self, measurement: float) -> float:
        self.p += self.q
        k = self.p / (self.p + self.r)
        self.x += k * (measurement - self.x)
        self.p *= (1.0 - k)
        return self.x


class SensorFusionService:
    WINDOW = 60  # samples kept for variance / rolling stats

    def __init__(self) -> None:
        self._speed_kf = SimpleKalman1D(process_noise=0.05, measurement_noise=0.5)
        self._lat_accel_kf = SimpleKalman1D(process_noise=0.02, measurement_noise=0.2)
        self._lon_accel_kf = SimpleKalman1D(process_noise=0.02, measurement_noise=0.2)
        self._yaw_kf = SimpleKalman1D(process_noise=0.01, measurement_noise=0.1)

        self._speed_history: Deque[float] = deque(maxlen=self.WINDOW)
        self._gyro_z_history: Deque[float] = deque(maxlen=self.WINDOW)
        self._accel_x_history: Deque[float] = deque(maxlen=self.WINDOW)
        self._prev_lon_accel: float = 0.0
        self._prev_ts: float = 0.0
        self._context_counter: dict = {c: 0 for c in RidingContext}

        self.current_state = FusedState()

    def update(self, raw: RawSensorData, traffic_object_count: int = 0) -> FusedState:
        dt = raw.timestamp - self._prev_ts if self._prev_ts > 0 else 0.033
        self._prev_ts = raw.timestamp

        # --- Speed: prefer GPS if accurate, else integrate accelerometer ---
        if raw.gps_accuracy_m < 10.0 and raw.gps_speed_kmh >= 0:
            speed = self._speed_kf.update(raw.gps_speed_kmh)
        else:
            # Dead reckoning from longitudinal accel (gravity-corrected)
            delta_v = (raw.accel_x) * dt * 3.6  # convert m/s to km/h
            speed = max(0.0, self._speed_kf.x + delta_v)
            speed = self._speed_kf.update(speed)

        self._speed_history.append(speed)

        # --- Lateral (left/right) acceleration ---
        lat_accel = self._lat_accel_kf.update(raw.accel_y)

        # --- Longitudinal (forward/back) acceleration ---
        lon_accel = self._lon_accel_kf.update(raw.accel_x)

        # --- Jerk (rate of change of longitudinal accel) ---
        jerk = abs(lon_accel - self._prev_lon_accel) / dt if dt > 0 else 0.0
        self._prev_lon_accel = lon_accel
        self._accel_x_history.append(lon_accel)

        # --- Yaw rate (gyro Z = steering) ---
        yaw = self._yaw_kf.update(raw.gyro_z)
        self._gyro_z_history.append(raw.gyro_z)

        # --- Lean angle estimation from lateral accel + speed ---
        lean_deg = math.degrees(math.atan2(lat_accel, 9.81)) if lat_accel != 0 else 0.0

        # --- Riding context ---
        context = self._classify_context(speed, traffic_object_count)

        state = FusedState(
            timestamp=raw.timestamp,
            speed_kmh=round(speed, 1),
            lateral_accel=round(lat_accel, 3),
            longitudinal_accel=round(lon_accel, 3),
            angular_velocity=round(yaw, 4),
            lean_angle=round(lean_deg, 1),
            heading=raw.gps_heading,
            lat=raw.gps_lat,
            lon=raw.gps_lon,
            jerk=round(jerk, 3),
            context=context,
        )
        self.current_state = state
        return state

    def _classify_context(self, speed: float, obj_count: int) -> RidingContext:
        if speed < 5:
            if obj_count > 5:
                return RidingContext.TRAFFIC_JAM
            return RidingContext.UNKNOWN
        if speed > 80:
            return RidingContext.HIGHWAY
        if obj_count == 0 and speed > 20:
            return RidingContext.EMPTY_ROAD
        return RidingContext.CITY_TRAFFIC

    # --- Derived metrics for behavior analysis ---

    def gyro_z_variance(self) -> float:
        if len(self._gyro_z_history) < 5:
            return 0.0
        return float(np.var(list(self._gyro_z_history)))

    def speed_std(self) -> float:
        if len(self._speed_history) < 3:
            return 0.0
        return float(np.std(list(self._speed_history)))

    def recent_max_braking(self, window: int = 10) -> float:
        recent = list(self._accel_x_history)[-window:]
        if not recent:
            return 0.0
        return abs(min(recent))  # most negative = hardest braking

    def smoothness_score(self) -> float:
        """0=rough, 100=smooth based on jerk variance."""
        if len(self._accel_x_history) < 5:
            return 100.0
        jerks = [abs(self._accel_x_history[i] - self._accel_x_history[i - 1])
                 for i in range(1, len(self._accel_x_history))]
        mean_jerk = float(np.mean(jerks))
        return max(0.0, 100.0 - mean_jerk * 20.0)
