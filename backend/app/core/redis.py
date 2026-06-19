import json
import logging
from typing import Any

from redis.asyncio import Redis

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

_redis: Redis | None = None


async def connect_redis() -> None:
    global _redis
    if _redis is not None:
        return
    try:
        _redis = Redis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5,
            health_check_interval=30,
        )
        await _redis.ping()
        logger.info("Redis connected")
    except Exception:
        _redis = None
        logger.exception("Redis connection failed")
        if settings.REDIS_REQUIRED:
            raise


async def close_redis() -> None:
    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None


def get_redis() -> Redis | None:
    return _redis


def redis_key(*parts: str) -> str:
    safe = [str(p).replace(":", "_") for p in parts if p]
    return ":".join([settings.REDIS_PREFIX, *safe])


async def cache_get_json(key: str) -> Any | None:
    client = get_redis()
    if client is None:
        return None
    raw = await client.get(key)
    if raw is None:
        return None
    return json.loads(raw)


async def cache_set_json(key: str, value: Any, ttl_seconds: int) -> None:
    client = get_redis()
    if client is None:
        return
    await client.set(key, json.dumps(value, default=str), ex=ttl_seconds)


async def cache_delete_pattern(pattern: str) -> None:
    client = get_redis()
    if client is None:
        return
    async for key in client.scan_iter(match=pattern, count=100):
        await client.delete(key)
