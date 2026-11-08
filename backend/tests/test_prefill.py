"""Tests for GET /v1/sessions/{session_id}/prefill passthrough.

Verifies that:
- The Bearer Authorization header is forwarded verbatim to the Bawarii platform.
- The response body is proxied without modification.
- 403 PREFILL_NOT_ENABLED responses are passed through unchanged.
"""

import os
import sys

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from main import app  # noqa: E402

UPSTREAM_BASE = "https://sandbox.api.bawarii.com"


@pytest.fixture()
def client() -> TestClient:
    with TestClient(app, raise_server_exceptions=True) as c:
        yield c


@respx.mock
def test_prefill_forwards_bearer_header(client: TestClient) -> None:
    """Bearer Authorization header must be forwarded to the upstream prefill endpoint."""
    session_id = "ses_prefill_bearer_001"
    upstream_response = {
        "session_id": session_id,
        "authoritative": False,
        "source": "device_side_ocr",
        "unverified_preview": {
            "national_id": "00-0000-001",
            "date_of_birth": "1980-01-01",
            "full_name": "TEST PERSON",
        },
    }
    route = respx.get(f"{UPSTREAM_BASE}/v1/sessions/{session_id}/prefill").mock(
        return_value=httpx.Response(200, json=upstream_response)
    )

    response = client.get(
        f"/v1/sessions/{session_id}/prefill",
        headers={"Authorization": "Bearer test-upload-token-xyz"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["session_id"] == session_id
    assert body["unverified_preview"]["full_name"] == "TEST PERSON"
    assert body["unverified_preview"]["national_id"] == "00-0000-001"

    # Bearer header must be forwarded verbatim.
    assert route.called
    sent_request = route.calls.last.request
    assert sent_request.headers.get("authorization") == "Bearer test-upload-token-xyz"


@respx.mock
def test_prefill_proxies_403_prefill_not_enabled(client: TestClient) -> None:
    """When prefill is disabled for a tenant, the 403 is proxied unchanged."""
    session_id = "ses_no_prefill"
    respx.get(f"{UPSTREAM_BASE}/v1/sessions/{session_id}/prefill").mock(
        return_value=httpx.Response(403, json={"detail": "PREFILL_NOT_ENABLED"})
    )

    response = client.get(
        f"/v1/sessions/{session_id}/prefill",
        headers={"Authorization": "Bearer pf-false-token"},
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "PREFILL_NOT_ENABLED"


@respx.mock
def test_prefill_without_auth_header_forwards_no_auth(client: TestClient) -> None:
    """Requests without Authorization are forwarded; upstream decides auth validity."""
    session_id = "ses_no_auth"
    route = respx.get(f"{UPSTREAM_BASE}/v1/sessions/{session_id}/prefill").mock(
        return_value=httpx.Response(401, json={"detail": "Unauthorized"})
    )

    response = client.get(f"/v1/sessions/{session_id}/prefill")

    assert response.status_code == 401
    assert route.called
    sent_request = route.calls.last.request
    assert "authorization" not in sent_request.headers
