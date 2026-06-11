from pydantic_settings import BaseSettings
from typing import Optional, List
import os
import secrets


class Settings(BaseSettings):
    PROJECT_NAME: str = "SafeChild API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"

    # ── Database ──────────────────────────────────────────────────────────────
    # Set DATABASE_URL in .env to use PostgreSQL (e.g. Neon)
    # Leave unset to fall back to local SQLite (development only)
    DATABASE_URL: Optional[str] = None

    # SQLite fallback (local dev only — NOT for production)
    SQLALCHEMY_DATABASE_URI: str = "sqlite:///./safechild.db"

    @property
    def get_database_uri(self) -> str:
        """Return the active database URI.
        Priority: DATABASE_URL env var > SQLALCHEMY_DATABASE_URI default (SQLite).
        """
        return self.DATABASE_URL or self.SQLALCHEMY_DATABASE_URI

    # ── JWT ───────────────────────────────────────────────────────────────────
    SECRET_KEY: str = os.getenv("SECRET_KEY", secrets.token_urlsafe(32))
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 8  # 8 days

    # ── CORS ───────────────────────────────────────────────────────────────────
    ALLOW_ALL_CORS: bool = False
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
