from app.core.redis import cache_delete_pattern, redis_key


async def invalidate_tenant_dashboard(tenant_id: str) -> None:
    await cache_delete_pattern(redis_key("dashboard", tenant_id, "*"))
