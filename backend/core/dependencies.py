"""
FastAPI dependency injection providers.

Services are imported lazily (inside the getter functions) to avoid circular
import issues at module load time.  Each heavy service is kept as a
module-level singleton and initialised on first use.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db

# ---------------------------------------------------------------------------
# Database dependency shorthand
# ---------------------------------------------------------------------------

# Re-export for convenience so callers only need to import from this module.
DatabaseDep = Annotated[AsyncSession, Depends(get_db)]

# ---------------------------------------------------------------------------
# Singleton service instances (initialised on first use)
# ---------------------------------------------------------------------------

_video_processor = None
_object_detector = None
_behavior_analyzer = None
_score_calculator = None
_sensor_fusion = None


async def get_video_processor():
    """Return (and lazily create) the shared VideoProcessor instance.

    Returns:
        The module-level VideoProcessor singleton.
    """
    global _video_processor
    if _video_processor is None:
        from services.video_processor import VideoProcessor

        _video_processor = VideoProcessor()
    return _video_processor


async def get_object_detector():
    """Return (and lazily create) the shared ObjectDetector instance.

    Returns:
        The module-level ObjectDetector singleton.
    """
    global _object_detector
    if _object_detector is None:
        from services.object_detector import ObjectDetector

        _object_detector = ObjectDetector()
    return _object_detector


async def get_behavior_analyzer():
    """Return (and lazily create) the shared BehaviorAnalyzer instance.

    Returns:
        The module-level BehaviorAnalyzer singleton.
    """
    global _behavior_analyzer
    if _behavior_analyzer is None:
        from services.behavior_analyzer import BehaviorAnalyzer

        _behavior_analyzer = BehaviorAnalyzer()
    return _behavior_analyzer


async def get_score_calculator():
    """Return (and lazily create) the shared ScoreCalculator instance.

    Returns:
        The module-level ScoreCalculator singleton.
    """
    global _score_calculator
    if _score_calculator is None:
        from services.score_calculator import ScoreCalculator

        _score_calculator = ScoreCalculator()
    return _score_calculator


async def get_sensor_fusion():
    """Return (and lazily create) the shared SensorFusion instance.

    Returns:
        The module-level SensorFusion singleton.
    """
    global _sensor_fusion
    if _sensor_fusion is None:
        from services.sensor_fusion import SensorFusion

        _sensor_fusion = SensorFusion()
    return _sensor_fusion


# ---------------------------------------------------------------------------
# Annotated dependency shorthands
# ---------------------------------------------------------------------------

VideoProcessorDep = Annotated[object, Depends(get_video_processor)]
ObjectDetectorDep = Annotated[object, Depends(get_object_detector)]
BehaviorAnalyzerDep = Annotated[object, Depends(get_behavior_analyzer)]
ScoreCalculatorDep = Annotated[object, Depends(get_score_calculator)]
SensorFusionDep = Annotated[object, Depends(get_sensor_fusion)]
