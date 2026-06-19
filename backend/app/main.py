from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from app.config import get_settings
from app.core.redis import close_redis, connect_redis, get_redis
from app.middleware.security import RateLimitMiddleware, SecurityHeadersMiddleware
from app.api import auth, customers, products, inventory, invoices, expenses, reports, dashboard
from app.api import settings as settings_api

app_settings = get_settings()

if app_settings.SENTRY_DSN:
    import sentry_sdk

    sentry_sdk.init(
        dsn=app_settings.SENTRY_DSN,
        environment=app_settings.ENVIRONMENT,
        traces_sample_rate=0.1 if app_settings.is_production else 1.0,
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_redis()
    yield
    await close_redis()


app = FastAPI(
    title=app_settings.APP_NAME,
    version=app_settings.APP_VERSION,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=app_settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Requested-With"],
)
if app_settings.trusted_hosts_list:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=app_settings.trusted_hosts_list)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(RateLimitMiddleware)


# Global error handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": "INTERNAL_ERROR",
            "message": "An unexpected error occurred",
        },
    )


# Health check
@app.get("/api/health")
async def health():
    return {"status": "healthy", "app": app_settings.APP_NAME, "version": app_settings.APP_VERSION}


@app.get("/api/ready")
async def ready():
    redis = get_redis()
    return {
        "status": "ready" if (redis is not None or not app_settings.REDIS_REQUIRED) else "degraded",
        "redis": redis is not None,
        "environment": app_settings.ENVIRONMENT,
    }


# Register routers
app.include_router(auth.router)
app.include_router(customers.router)
app.include_router(products.router)
app.include_router(inventory.router)
app.include_router(invoices.router)
app.include_router(expenses.router)
app.include_router(reports.router)
app.include_router(dashboard.router)
app.include_router(settings_api.router)
