"""Tests for POST /reference/start_kyc.

Uses respx to mock the upstream Bawarii API so no real network calls are made.
"""

import json
import os
import sys

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

# Inject required env vars before importing config / main.
os.environ.setdefault("BAWARII_API_KEY", "bk_test_abc123")
os.environ.setdefault("BAWARII_WEBHOOK_SECRET", "test-webhook-secret")

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from config import settings  # noqa: E402
from main import app  # noqa: E402

UPSTREAM_BASE = "https://sandbox.api.bawarii.com"


@pytest.fixture()
def client() -> TestClient:
    with TestClient(app, raise_server_exceptions=True) as c:
        yield c


# ─── Happy path ───────────────────────────────────────────────────────────────


@respx.mock
def test_start_kyc_sends_correct_body_and_api_key(client: TestClient) -> None:
    upstream_response = {
        "session_id": "ses_xyz",
        "upload_token": "tok_abc",
        "expires_at": "2026-05-23T12:00:00Z",
        "workflow": "document_and_liveness",
    }
    route = respx.post(f"{UPSTREAM_BASE}/v1/sessions").mock(
        return_value=httpx.Response(201, json=upstream_response)
    )

    response = client.post(
        "/reference/start_kyc",
        json={
            "document_type": "national_id",
            "reference_id": "ref-001",
            "workflow": "document_and_liveness",
        },
    )

    assert response.status_code == 200
    configured = settings.REFERENCE_BACKEND_PUBLIC_URL
    expected_base = configured.rstrip("/") if configured else "http://testserver"
    assert response.json() == {**upstream_response, "upload_base_url": expected_base}

    # Verify the correct body was sent upstream.
    assert route.called
    sent_request = route.calls.last.request
    import json
    sent_body = json.loads(sent_request.content)
    assert sent_body["document_type"] == "national_id"
    assert sent_body["reference_id"] == "ref-001"
    assert sent_body["workflow"] == "document_and_liveness"

    # Verify X-API-Key header was attached.
    assert sent_request.headers["X-API-Key"] == "bk_test_abc123"


# ─── Upstream 403 passthrough ─────────────────────────────────────────────────


@respx.mock
def test_upstream_403_is_proxied(client: TestClient) -> None:
    respx.post(f"{UPSTREAM_BASE}/v1/sessions").mock(
        return_value=httpx.Response(403, json={"detail": "Forbidden"})
    )

    response = client.post(
        "/reference/start_kyc",
        json={
            "document_type": "national_id",
            "reference_id": "ref-002",
        },
    )

    assert response.status_code == 403


@respx.mock
def test_create_session_payload_has_no_webhook_url(client: TestClient) -> None:
    """The webhook URL is configured for the tenant in the developer portal,
    never per session."""
    route = respx.post(f"{UPSTREAM_BASE}/v1/sessions").mock(
        return_value=httpx.Response(201, json={"session_id": "ses_1"})
    )

    client.post(
        "/reference/start_kyc",
        json={"document_type": "e_tazkira", "reference_id": "ref-1"},
    )

    assert route.called
    assert "webhook_url" not in json.loads(route.calls.last.request.content)
