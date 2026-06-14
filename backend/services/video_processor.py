"""
OpenCV-based video stream processor.
Handles RTSP / MJPEG streams and exposes frames for downstream AI analysis.
"""
from __future__ import annotations

import asyncio
import logging
import time
from typing import AsyncGenerator, Optional, Tuple

import cv2
import numpy as np

logger = logging.getLogger(__name__)


class VideoProcessor:
    """Captures frames from an RTSP/MJPEG/file source."""

    def __init__(
        self,
        source: str = "rtsp://10.5.5.9:554/live",
        target_fps: int = 15,
        resize: Tuple[int, int] = (640, 480),
    ) -> None:
        self._source = source
        self._target_fps = target_fps
        self._resize = resize
        self._cap: Optional[cv2.VideoCapture] = None
        self._frame_interval = 1.0 / target_fps
        self._last_frame_time = 0.0

    def open(self) -> bool:
        self._cap = cv2.VideoCapture(self._source)
        self._cap.set(cv2.CAP_PROP_BUFFERSIZE, 2)
        if not self._cap.isOpened():
            logger.error("Cannot open video source: %s", self._source)
            return False
        logger.info("Video source opened: %s", self._source)
        return True

    def release(self) -> None:
        if self._cap:
            self._cap.release()
            self._cap = None

    def read_frame(self) -> Optional[np.ndarray]:
        if self._cap is None:
            return None
        ret, frame = self._cap.read()
        if not ret:
            return None
        frame = cv2.resize(frame, self._resize)
        return frame

    def preprocess(self, frame: np.ndarray) -> np.ndarray:
        """Normalize and denoise frame for AI inference."""
        frame = cv2.GaussianBlur(frame, (3, 3), 0)
        return frame

    def encode_jpeg(self, frame: np.ndarray, quality: int = 70) -> bytes:
        """Encode frame as JPEG bytes for WebSocket transmission."""
        _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, quality])
        return buf.tobytes()

    def decode_jpeg(self, data: bytes) -> Optional[np.ndarray]:
        """Decode JPEG bytes received from mobile client."""
        arr = np.frombuffer(data, dtype=np.uint8)
        frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if frame is None:
            return None
        return cv2.resize(frame, self._resize)

    async def frame_generator(self) -> AsyncGenerator[np.ndarray, None]:
        """Async generator that yields frames at the target FPS."""
        if not self.open():
            return
        try:
            while True:
                now = time.monotonic()
                if now - self._last_frame_time < self._frame_interval:
                    await asyncio.sleep(self._frame_interval * 0.1)
                    continue
                frame = self.read_frame()
                if frame is None:
                    logger.warning("Empty frame — reconnecting in 1s")
                    await asyncio.sleep(1.0)
                    self.open()
                    continue
                self._last_frame_time = now
                yield self.preprocess(frame)
        finally:
            self.release()

    def draw_detections(
        self,
        frame: np.ndarray,
        detections: list,
        warnings: list,
    ) -> np.ndarray:
        """Draw bounding boxes and warning overlay on a frame."""
        overlay = frame.copy()
        _COLORS = {
            "car": (0, 200, 255),
            "truck": (255, 100, 0),
            "motorcycle": (0, 255, 100),
            "person": (255, 255, 0),
            "bicycle": (180, 255, 180),
            "bus": (200, 50, 255),
        }
        for det in detections:
            x1, y1, x2, y2 = det["bbox"]
            color = _COLORS.get(det["class_name"], (200, 200, 200))
            cv2.rectangle(overlay, (x1, y1), (x2, y2), color, 2)
            label = f"{det['class_name']} {det['confidence']:.2f}"
            if det.get("distance_m"):
                label += f" {det['distance_m']:.0f}m"
            cv2.putText(overlay, label, (x1, y1 - 6),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.55, color, 1, cv2.LINE_AA)

        # Warning banner at top
        if warnings:
            cv2.rectangle(overlay, (0, 0), (frame.shape[1], 36), (0, 0, 200), -1)
            cv2.putText(overlay, " | ".join(warnings), (8, 24),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1, cv2.LINE_AA)

        return cv2.addWeighted(overlay, 0.85, frame, 0.15, 0)
