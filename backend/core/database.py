"""
Async SQLAlchemy engine, session factory, and declarative base.

All database interaction in the application should go through the
``get_db`` FastAPI dependency so that sessions are properly scoped to
each request and automatically closed on completion.
"""

from __future__ import annotations

import logging
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from core.config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Engine
# ---------------------------------------------------------------------------

engine: AsyncEngine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
)

# ---------------------------------------------------------------------------
# Session factory
# ---------------------------------------------------------------------------

async_session_maker: async_sessionmaker[AsyncSession] = async_sessionmaker(
    bind=engine,
    expire_on_commit=False,
)

# ---------------------------------------------------------------------------
# Declarative base
# ---------------------------------------------------------------------------


class Base(DeclarativeBase):
    """Shared declarative base for all ORM models."""

    pass


# ---------------------------------------------------------------------------
# Lifecycle helpers
# ---------------------------------------------------------------------------


async def init_db() -> None:
    """Create all tables registered with ``Base.metadata``.

    Should be called once during application startup. In production,
    prefer Alembic migrations over this function for schema management.
    """
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Database tables created (or already exist).")


async def close_db() -> None:
    """Dispose of the async engine and release all pooled connections.

    Should be called once during application shutdown.
    """
    await engine.dispose()
    logger.info("Database engine disposed.")


# ---------------------------------------------------------------------------
# FastAPI dependency
# ---------------------------------------------------------------------------


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency that yields a per-request async database session.

    The session is committed automatically when the request handler returns
    without raising an exception.  Any exception causes an automatic
    rollback before the session is closed.

    Yields:
        An ``AsyncSession`` bound to the shared engine.
    """
    async with async_session_maker() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
