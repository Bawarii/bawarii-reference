"""
Pytest configuration for reference backend tests.

Sets BAWARII_API_BASE_URL before any app module is imported so pydantic-settings
picks up the env var (higher priority than .env), ensuring all tests mock the
same URL (`https://sandbox.api.bawarii.com` — the documented Bawarii platform default).
"""

import os

os.environ.setdefault("BAWARII_API_BASE_URL", "https://sandbox.api.bawarii.com")
os.environ.setdefault("BAWARII_API_KEY", "bk_test_abc123")
os.environ.setdefault("BAWARII_WEBHOOK_SECRET", "test-webhook-secret")
