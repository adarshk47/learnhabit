"""
Ride CRUD endpoints.

POST   /rides              — create a new ride session
GET    /rides              — list rides (paginated)
GET    /rides/{ride_id}    — get a single ride
DELETE /rides/{ride_id}    — delete a ride
PATCH  /rides/{ride_id}/status — update ride status
GET    /rides/{ride_id}/events — list events for a ride
POST   /rides/{ride_id}/events — add an event to a ride
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from core.database import get_db
from models.ride import Ride, RideEvent, RideStatus
from schemas.ride import (
    RideCreate,
    RideEventCreate,
    RideEventResponse,
    RideListResponse,
    RideResponse,
    RideStatusUpdate,
    RideUpdate,
)

logger = logging.getLogger(__name__)
router = APIRouter()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _get_ride_or_404(ride_id: str, db: AsyncSession) -> Ride:
    ride = await db.get(Ride, ride_id)
    if ride is None:
        raise HTTPException(status_code=404, detail=f"Ride {ride_id!r} not found.")
    return ride


# ---------------------------------------------------------------------------
# Ride endpoints
# ---------------------------------------------------------------------------


@router.post(
    "",
    response_model=RideResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new ride session",
)
async def create_ride(
    payload: RideCreate,
    db: AsyncSession = Depends(get_db),
) -> Ride:
    """Create a new ride record in *pending* status."""
    ride = Ride(
        user_id=payload.user_id,
        title=payload.title,
        video_source=payload.video_source,
        status=RideStatus.pending,
        start_time=datetime.now(timezone.utc),
    )
    db.add(ride)
    try:
        await db.commit()
        await db.refresh(ride)
    except Exception as exc:
        await db.rollback()
        logger.exception("Failed to create ride: %s", exc)
        raise HTTPException(status_code=500, detail="Could not create ride.")
    logger.info("Created ride %s for user %s", ride.id, ride.user_id)
    return ride


@router.get(
    "",
    response_model=RideListResponse,
    summary="List rides (paginated)",
)
async def list_rides(
    skip: int = Query(default=0, ge=0, description="Number of records to skip"),
    limit: int = Query(default=50, ge=1, le=200, description="Max records to return"),
    user_id: str | None = Query(default=None, description="Filter by user ID"),
    db: AsyncSession = Depends(get_db),
) -> RideListResponse:
    """Return a paginated list of rides, optionally filtered by user."""
    stmt = select(Ride).order_by(Ride.created_at.desc())
    count_stmt = select(func.count()).select_from(Ride)

    if user_id:
        stmt = stmt.where(Ride.user_id == user_id)
        count_stmt = count_stmt.where(Ride.user_id == user_id)

    total_result = await db.execute(count_stmt)
    total = total_result.scalar_one()

    result = await db.execute(stmt.offset(skip).limit(limit))
    rides = list(result.scalars().all())

    return RideListResponse(total=total, skip=skip, limit=limit, items=rides)


@router.get(
    "/{ride_id}",
    response_model=RideResponse,
    summary="Get a ride by ID",
)
async def get_ride(
    ride_id: str,
    db: AsyncSession = Depends(get_db),
) -> Ride:
    return await _get_ride_or_404(ride_id, db)


@router.delete(
    "/{ride_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a ride",
)
async def delete_ride(
    ride_id: str,
    db: AsyncSession = Depends(get_db),
) -> None:
    ride = await _get_ride_or_404(ride_id, db)
    try:
        await db.delete(ride)
        await db.commit()
    except Exception as exc:
        await db.rollback()
        logger.exception("Failed to delete ride %s: %s", ride_id, exc)
        raise HTTPException(status_code=500, detail="Could not delete ride.")
    logger.info("Deleted ride %s", ride_id)


@router.patch(
    "/{ride_id}",
    response_model=RideResponse,
    summary="Update ride metadata",
)
async def update_ride(
    ride_id: str,
    payload: RideUpdate,
    db: AsyncSession = Depends(get_db),
) -> Ride:
    """Partially update ride title, video_source, distance, or duration."""
    ride = await _get_ride_or_404(ride_id, db)
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(ride, field, value)
    try:
        await db.commit()
        await db.refresh(ride)
    except Exception as exc:
        await db.rollback()
        logger.exception("Failed to update ride %s: %s", ride_id, exc)
        raise HTTPException(status_code=500, detail="Could not update ride.")
    return ride


@router.patch(
    "/{ride_id}/status",
    response_model=RideResponse,
    summary="Update ride status",
)
async def update_ride_status(
    ride_id: str,
    payload: RideStatusUpdate,
    db: AsyncSession = Depends(get_db),
) -> Ride:
    """Transition a ride to a new status.

    When transitioning to *active*, ``start_time`` is set to now (if not already).
    When transitioning to *completed* or *failed*, ``end_time`` is set to now.
    """
    ride = await _get_ride_or_404(ride_id, db)
    ride.status = payload.status

    now = datetime.now(timezone.utc)
    if payload.status == RideStatus.active and ride.start_time is None:
        ride.start_time = now
    elif payload.status in (RideStatus.completed, RideStatus.failed):
        ride.end_time = now
        if ride.start_time:
            delta = (now - ride.start_time).total_seconds()
            ride.duration_seconds = max(0, int(delta))

    try:
        await db.commit()
        await db.refresh(ride)
    except Exception as exc:
        await db.rollback()
        logger.exception("Failed to update status of ride %s: %s", ride_id, exc)
        raise HTTPException(status_code=500, detail="Could not update ride status.")
    return ride


# ---------------------------------------------------------------------------
# RideEvent sub-resource
# ---------------------------------------------------------------------------


@router.get(
    "/{ride_id}/events",
    response_model=List[RideEventResponse],
    summary="List events for a ride",
)
async def list_ride_events(
    ride_id: str,
    db: AsyncSession = Depends(get_db),
) -> List[RideEvent]:
    """Return all riding events recorded for a specific ride."""
    await _get_ride_or_404(ride_id, db)
    result = await db.execute(
        select(RideEvent)
        .where(RideEvent.ride_id == ride_id)
        .order_by(RideEvent.timestamp.asc())
    )
    return list(result.scalars().all())


@router.post(
    "/{ride_id}/events",
    response_model=RideEventResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add an event to a ride",
)
async def create_ride_event(
    ride_id: str,
    payload: RideEventCreate,
    db: AsyncSession = Depends(get_db),
) -> RideEvent:
    """Record a new riding event (hard braking, speeding, etc.) for a ride."""
    await _get_ride_or_404(ride_id, db)
    event = RideEvent(
        ride_id=ride_id,
        event_type=payload.event_type,
        severity=payload.severity,
        timestamp=payload.timestamp or datetime.now(timezone.utc),
        latitude=payload.latitude,
        longitude=payload.longitude,
        speed_kmph=payload.speed_kmph,
        description=payload.description,
        metadata_json=payload.metadata_json,
    )
    db.add(event)
    try:
        await db.commit()
        await db.refresh(event)
    except Exception as exc:
        await db.rollback()
        logger.exception("Failed to create event for ride %s: %s", ride_id, exc)
        raise HTTPException(status_code=500, detail="Could not create event.")
    return event
