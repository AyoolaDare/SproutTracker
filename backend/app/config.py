from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings
from functools import lru_cache
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Sprout Track"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ENVIRONMENT: str = "development"
    FRONTEND_URL: str = "http://localhost:3000"
    VERIFY_FRONTEND_URL: str = ""
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:4174"
    TRUSTED_HOSTS: str = "localhost,127.0.0.1"

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://sprout:sprout@localhost:5432/sprout"
    DATABASE_URL_SYNC: str = "postgresql://sprout:sprout@localhost:5432/sprout"
    DB_POOL_SIZE: int = 5
    DB_MAX_OVERFLOW: int = 5

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
    SMTP_FROM_EMAIL: str = ""
    SMTP_FROM_NAME: str = "Sprout Track"
    BREVO_API_KEY: str = ""

    # Social sign-in
    GOOGLE_CLIENT_ID: str = ""

    # Observability
    SENTRY_DSN: str = ""

    # Temporary production diagnostics. Leave blank unless actively testing.
    DIAGNOSTIC_TOKEN: str = ""

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
    def verify_frontend_url(self) -> str:
        return (self.VERIFY_FRONTEND_URL or self.FRONTEND_URL).rstrip("/")

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
            value = value.replace("postgresql://", "postgresql+asyncpg://", 1)
        # asyncpg does not accept libpq-style sslmode query parameters.
        value = value.replace("?sslmode=require", "?ssl=require")
        value = value.replace("&sslmode=require", "&ssl=require")
        # Supabase's transaction/session pooler can reuse backend connections across
        # clients, so asyncpg prepared statement cache must be disabled explicitly.
        if value.startswith("postgresql+asyncpg://"):
            parts = urlsplit(value)
            query = dict(parse_qsl(parts.query, keep_blank_values=True))
            query.setdefault("prepared_statement_cache_size", "0")
            value = urlunsplit(
                (parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment)
            )
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
        if "REPLACE_" in self.DATABASE_URL or "REPLACE_" in self.DATABASE_URL_SYNC:
            raise ValueError("DATABASE_URL values still contain placeholders.")
        if "REPLACE_" in self.FRONTEND_URL or "your-" in self.FRONTEND_URL:
            raise ValueError("FRONTEND_URL must be set to the deployed frontend URL.")
        if "localhost" in self.FRONTEND_URL or "127.0.0.1" in self.FRONTEND_URL:
            raise ValueError("FRONTEND_URL cannot be localhost in production.")
        if self.VERIFY_FRONTEND_URL:
            if "REPLACE_" in self.VERIFY_FRONTEND_URL or "your-" in self.VERIFY_FRONTEND_URL:
                raise ValueError("VERIFY_FRONTEND_URL contains a placeholder value.")
            if "localhost" in self.VERIFY_FRONTEND_URL or "127.0.0.1" in self.VERIFY_FRONTEND_URL:
                raise ValueError("VERIFY_FRONTEND_URL cannot be localhost in production.")
        if "*" in self.cors_origins_list:
            raise ValueError("CORS_ORIGINS cannot include '*' when credentials are enabled.")
        if any("localhost" in origin or "127.0.0.1" in origin for origin in self.cors_origins_list):
            raise ValueError("CORS_ORIGINS cannot include localhost in production.")
        if any("REPLACE_" in host or "your-" in host for host in self.trusted_hosts_list):
            raise ValueError("TRUSTED_HOSTS contains placeholder values.")
        if set(self.trusted_hosts_list).issubset({"localhost", "127.0.0.1"}):
            raise ValueError("TRUSTED_HOSTS must include deployed backend hostnames in production.")
        if self.REDIS_REQUIRED and not self.REDIS_URL:
            raise ValueError("REDIS_URL is required when REDIS_REQUIRED=true.")
        if self.REDIS_REQUIRED and "REPLACE_" in self.REDIS_URL:
            raise ValueError("REDIS_URL still contains placeholders.")
        smtp_configured = all(
            [
                self.SMTP_HOST,
                self.SMTP_USER,
                self.SMTP_PASSWORD,
                self.SMTP_FROM_EMAIL,
            ]
        )
        brevo_configured = bool(self.BREVO_API_KEY and self.SMTP_FROM_EMAIL)
        if not smtp_configured and not brevo_configured:
            raise ValueError("Production email is not configured. Set BREVO_API_KEY and SMTP_FROM_EMAIL.")
        if self.SMTP_FROM_EMAIL and ("REPLACE_" in self.SMTP_FROM_EMAIL or "yourdomain.com" in self.SMTP_FROM_EMAIL):
            raise ValueError("SMTP_FROM_EMAIL must be a verified production sender.")
        return self


@lru_cache()
def get_settings() -> Settings:
    return Settings()
