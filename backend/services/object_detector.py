"""
YOLOv8-based object detector for bikes, cars, trucks, pedestrians, and traffic lanes.
Includes per-class distance estimation from bounding box size.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np

logger = logging.getLogger(__name__)

# YOLOv8 COCO class IDs we care about
_COCO_CLASSES = {
    0: "person",
    1: "bicycle",
    2: "car",
    3: "motorcycle",
    5: "bus",
    7: "truck",
    9: "traffic light",
    11: "stop sign",
}

# Real-world heights (m) used for distance estimation via pinhole model
_REAL_HEIGHTS_M: Dict[str, float] = {
    "person": 1.75,
    "car": 1.5,
    "truck": 4.0,
    "bus": 3.5,
    "motorcycle": 1.1,
    "bicycle": 1.1,
}

# Focal length assumption (pixels) — calibrated for ~1080p action camera
_FOCAL_LENGTH_PX = 800.0


@dataclass
class DetectedObject:
    class_name: str
    confidence: float
    bbox: Tuple[int, int, int, int]   # x1, y1, x2, y2
    distance_m: Optional[float] = None
    track_id: Optional[int] = None


@dataclass
class DetectionResult:
    objects: List[DetectedObject] = field(default_factory=list)
    traffic_density: float = 0.0     # 0–1 normalised
    lane_deviation: float = 0.0      # pixels from centre
    oncoming_vehicle: bool = False
    frame_width: int = 640
    frame_height: int = 480

    @property
    def vehicle_count(self) -> int:
        vehicle_classes = {"car", "truck", "bus", "motorcycle", "bicycle"}
        return sum(1 for o in self.objects if o.class_name in vehicle_classes)

    @property
    def nearest_vehicle_m(self) -> Optional[float]:
        dists = [o.distance_m for o in self.objects if o.distance_m is not None
                 and o.class_name in {"car", "truck", "bus", "motorcycle"}]
        return min(dists) if dists else None

    def to_dict(self) -> dict:
        return {
            "objects": [
                {
                    "class_name": o.class_name,
                    "confidence": round(o.confidence, 3),
                    "bbox": list(o.bbox),
                    "distance_m": round(o.distance_m, 1) if o.distance_m else None,
                    "track_id": o.track_id,
                }
                for o in self.objects
            ],
            "traffic_density": round(self.traffic_density, 2),
            "lane_deviation": round(self.lane_deviation, 1),
            "oncoming_vehicle": self.oncoming_vehicle,
            "vehicle_count": self.vehicle_count,
            "nearest_vehicle_m": (
                round(self.nearest_vehicle_m, 1) if self.nearest_vehicle_m else None
            ),
        }


class ObjectDetector:
    """Wraps YOLOv8 for per-frame inference with optional GPU acceleration."""

    def __init__(self, model_path: str = "yolov8n.pt", conf: float = 0.45) -> None:
        self._model_path = model_path
        self._conf = conf
        self._model = None
        self._loaded = False
        self._track_id_counter = 0

    def load(self) -> None:
        try:
            from ultralytics import YOLO
            self._model = YOLO(self._model_path)
            self._loaded = True
            logger.info("YOLOv8 model loaded: %s", self._model_path)
        except Exception as exc:
            logger.warning("YOLOv8 load failed (%s) — running in mock mode", exc)

    def detect(self, frame: np.ndarray) -> DetectionResult:
        if not self._loaded or self._model is None:
            return self._mock_detect(frame)
        return self._real_detect(frame)

    def _real_detect(self, frame: np.ndarray) -> DetectionResult:
        h, w = frame.shape[:2]
        results = self._model.track(
            frame, conf=self._conf, persist=True, verbose=False
        )
        objects: List[DetectedObject] = []
        for r in results:
            if r.boxes is None:
                continue
            for box in r.boxes:
                cls_id = int(box.cls[0])
                if cls_id not in _COCO_CLASSES:
                    continue
                cls_name = _COCO_CLASSES[cls_id]
                conf = float(box.conf[0])
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                track_id = int(box.id[0]) if box.id is not None else None
                distance = self._estimate_distance(cls_name, y2 - y1)
                objects.append(DetectedObject(
                    class_name=cls_name,
                    confidence=conf,
                    bbox=(x1, y1, x2, y2),
                    distance_m=distance,
                    track_id=track_id,
                ))

        density = min(1.0, len(objects) / 10.0)
        lane_dev = self._estimate_lane_deviation(frame, w)
        oncoming = self._detect_oncoming(objects, w)

        return DetectionResult(
            objects=objects,
            traffic_density=density,
            lane_deviation=lane_dev,
            oncoming_vehicle=oncoming,
            frame_width=w,
            frame_height=h,
        )

    def _estimate_distance(self, class_name: str, bbox_height_px: int) -> Optional[float]:
        real_h = _REAL_HEIGHTS_M.get(class_name)
        if real_h is None or bbox_height_px <= 0:
            return None
        return round((_FOCAL_LENGTH_PX * real_h) / bbox_height_px, 1)

    def _estimate_lane_deviation(self, frame: np.ndarray, width: int) -> float:
        """Simple Hough-line lane deviation — returns pixel offset from centre."""
        try:
            import cv2
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            edges = cv2.Canny(gray, 50, 150)
            roi = edges[int(frame.shape[0] * 0.55):, :]
            lines = cv2.HoughLinesP(roi, 1, np.pi / 180, 40, minLineLength=50, maxLineGap=20)
            if lines is None:
                return 0.0
            cx = width / 2
            midpoints = [(l[0][0] + l[0][2]) / 2 for l in lines]
            lane_cx = float(np.mean(midpoints))
            return lane_cx - cx
        except Exception:
            return 0.0

    def _detect_oncoming(self, objects: List[DetectedObject], frame_width: int) -> bool:
        for obj in objects:
            if obj.class_name in {"car", "truck", "motorcycle"}:
                x1, _, x2, _ = obj.bbox
                obj_cx = (x1 + x2) / 2
                if obj_cx < frame_width * 0.4 and obj.distance_m and obj.distance_m < 30:
                    return True
        return False

    def _mock_detect(self, frame: np.ndarray) -> DetectionResult:
        """Returns empty result when model isn't loaded (dev/test mode)."""
        return DetectionResult(
            frame_width=frame.shape[1] if frame.ndim == 3 else 640,
            frame_height=frame.shape[0] if frame.ndim == 3 else 480,
        )
