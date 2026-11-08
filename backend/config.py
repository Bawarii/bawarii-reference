from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=(Path(__file__).parent.parent / ".env", ".env"), env_file_encoding="utf-8")

    BAWARII_API_BASE_URL: str = "https://sandbox.api.bawarii.com"
    BAWARII_API_KEY: str  # required — startup fails if absent
    BAWARII_WEBHOOK_SECRET: str  # required — startup fails if absent
    REFERENCE_BACKEND_PORT: int = 8000
    # Public URL of this backend (e.g. ngrok URL for physical device testing).
    # The SDK uses this as the base URL for document/biometric uploads, which
    # are proxied here to the Bawarii platform. If unset, falls back to localhost.
    REFERENCE_BACKEND_PUBLIC_URL: str | None = None
    LOG_LEVEL: str = "INFO"


settings = Settings()
