from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Sprout Track"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ENVIRONMENT: str = "development"
    FRONTEND_URL: str = "http://localhost:3000"
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:4174"
    TRUSTED_HOSTS: str = "localhost,127.0.0.1"

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://sprout:sprout@localhost:5432/sprout"
    DATABASE_URL_SYNC: str = "postgresql://sprout:sprout@localhost:5432/sprout"

    # Redis / Upstash
    REDIS_URL: str = "redis://localhost:6379"
    REDIS_PREFIX: str = "sprout-track"
    REDIS_REQUIRED: bool = False

    # JWT
    JWT_SECRET: str = "change-me-in-production-use-a-real-secret-key"
    JWT_REFRESH_SECRET: str = "change-me-refresh-secret-key"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Rate Limiting
    RATE_LIMIT_LOGIN: int = 5  # per minute per IP
    RATE_LIMIT_API: int = 60  # per minute per user
    RATE_LIMIT_WINDOW_SECONDS: int = 60

    # Caching
    DASHBOARD_CACHE_SECONDS: int = 60

    # Supabase Storage
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_STORAGE_BUCKET: str = "sprout-track"
    UPLOAD_DIR: str = "./uploads"
    MAX_UPLOAD_SIZE: int = 10 * 1024 * 1024  # 10MB

    # Email (SMTP)
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""

    # Observability
    SENTRY_DSN: str = ""

    model_config = {"env_file": ".env", "extra": "ignore"}

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT.lower() == "production"

    @property
    def cors_origins_list(self) -> list[str]:
        values = [self.FRONTEND_URL, *self.CORS_ORIGINS.split(",")]
        return sorted({v.strip().rstrip("/") for v in values if v.strip()})

    @property
    def trusted_hosts_list(self) -> list[str]:
        values = [*self.TRUSTED_HOSTS.split(",")]
        return [v.strip() for v in values if v.strip()]

    @property
    def sync_database_url(self) -> str:
        default_sync = "postgresql://sprout:sprout@localhost:5432/sprout"
        if self.DATABASE_URL_SYNC != default_sync:
            return self.DATABASE_URL_SYNC
        return self.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://", 1)

    @field_validator("DATABASE_URL")
    @classmethod
    def normalize_async_database_url(cls, value: str) -> str:
        # Supabase often provides postgresql:// URLs. SQLAlchemy async needs asyncpg.
        if value.startswith("postgresql://"):
            return value.replace("postgresql://", "postgresql+asyncpg://", 1)
        return value

    @field_validator("DEBUG", mode="before")
    @classmethod
    def parse_debug_flag(cls, value):
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"release", "prod", "production"}:
                return False
            if normalized in {"debug", "dev", "development"}:
                return True
        return value

    @field_validator("DATABASE_URL_SYNC")
    @classmethod
    def normalize_sync_database_url(cls, value: str) -> str:
        if value.startswith("postgresql+asyncpg://"):
            return value.replace("postgresql+asyncpg://", "postgresql://", 1)
        return value

    @model_validator(mode="after")
    def validate_production_settings(self):
        if not self.is_production:
            return self

        weak_values = {
            "change-me-in-production-use-a-real-secret-key",
            "change-me-refresh-secret-key",
            "change-me-in-production",
            "change-me-refresh-production",
        }
        if self.JWT_SECRET in weak_values or len(self.JWT_SECRET) < 32:
            raise ValueError("JWT_SECRET must be set to a strong production secret.")
        if self.JWT_REFRESH_SECRET in weak_values or len(self.JWT_REFRESH_SECRET) < 32:
            raise ValueError("JWT_REFRESH_SECRET must be set to a strong production secret.")
        if "localhost" in self.DATABASE_URL:
            raise ValueError("DATABASE_URL must point to Supabase/Postgres in production.")
        if self.REDIS_REQUIRED and not self.REDIS_URL:
            raise ValueError("REDIS_URL is required when REDIS_REQUIRED=true.")
        return self


@lru_cache()
def get_settings() -> Settings:
    return Settings()
