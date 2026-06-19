import time
from collections.abc import Awaitable, Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

from app.config import get_settings
from app.core.redis import get_redis, redis_key

settings = get_settings()


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        if settings.is_production:
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        if request.method == "OPTIONS" or request.url.path in {"/api/health", "/api/ready"}:
            return await call_next(request)
        if not request.url.path.startswith("/api/"):
            return await call_next(request)

        redis = get_redis()
        if redis is None:
            return await call_next(request)

        is_login = request.url.path == "/api/auth/login"
        limit = settings.RATE_LIMIT_LOGIN if is_login else settings.RATE_LIMIT_API
        window = settings.RATE_LIMIT_WINDOW_SECONDS
        subject = self._subject(request, is_login=is_login)
        bucket = int(time.time() // window)
        key = redis_key("rate", subject, str(bucket))

        count = await redis.incr(key)
        if count == 1:
            await redis.expire(key, window + 5)
        if count > limit:
            return Response(
                content='{"detail":"Rate limit exceeded"}',
                status_code=429,
                media_type="application/json",
                headers={"Retry-After": str(window)},
            )

        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(max(0, limit - count))
        return response

    @staticmethod
    def _subject(request: Request, *, is_login: bool) -> str:
        if is_login:
            forwarded = request.headers.get("x-forwarded-for", "")
            return f"ip:{forwarded.split(',')[0].strip() or (request.client.host if request.client else 'unknown')}"
        auth = request.headers.get("authorization", "")
        if auth.lower().startswith("bearer "):
            return f"token:{auth[7:31]}"
        return f"ip:{request.client.host if request.client else 'unknown'}"
