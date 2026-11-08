"""Tests for GET /reference/result/{session_id}.

Verifies that the upstream response, including PII fields, is proxied verbatim.
"""

import os
import sys

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

os.environ.setdefault("BAWARII_API_KEY", "bk_test_abc123")
os.environ.setdefault("BAWARII_WEBHOOK_SECRET", "test-webhook-secret")

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from main import app  # noqa: E402

UPSTREAM_BASE = "https://sandbox.api.bawarii.com"


@pytest.fixture()
def client() -> TestClient:
    with TestClient(app, raise_server_exceptions=True) as c:
        yield c


@respx.mock
def test_get_result_proxies_pii_fields(client: TestClient) -> None:
    upstream_body = {
        "session_id": "ses_xyz",
        "status": "APPROVED",
        "verdict": "APPROVED",
        "document_type": "national_id",
        "reference_id": "ref-001",
        "workflow": "document_and_liveness",
        "checked_at": "2026-05-23T11:00:00Z",
        # PII — must pass through without modification
        "full_name": "TEST PERSON",
        "national_id_number": "12345678",
        "date_of_birth": "1985-03-12",
        "match_score": 0.97,
    }
    respx.get(f"{UPSTREAM_BASE}/v1/sessions/ses_xyz/result").mock(
        return_value=httpx.Response(200, json=upstream_body)
    )

    response = client.get("/reference/result/ses_xyz")

    assert response.status_code == 200
    body = response.json()
    assert body["full_name"] == "TEST PERSON"
    assert body["national_id_number"] == "12345678"
    assert body["match_score"] == 0.97
    assert body["verdict"] == "APPROVED"


@respx.mock
def test_get_result_proxies_extraction_meta_verbatim(client: TestClient) -> None:
    """extraction_meta (X-API-Key only, additive on the platform
    side) must pass through this proxy untouched — get_result / GET
    /reference/result do no field filtering, they forward the upstream JSON
    body as-is (see BawariiClient.get_result and main.get_result)."""
    upstream_body = {
        "session_id": "ses_meta",
        "verdict": "APPROVED",
        "workflow": "document_and_liveness",
        "reference_id": "ref-meta",
        "extraction_meta": {
            "field_confidences": {
                "national_id": 0.95,
                "surname_latin": 0.90,
                "given_name_latin": 0.50,
            },
            "sides": {
                "front": {
                    "status": "ACCEPTED",
                    "issues": [],
                    "ocr_confidence": 0.93,
                    "mrz_valid": None,
                },
                "back": {
                    "status": "ACCEPTED",
                    "issues": ["NAME_TOKEN_REPAIRED"],
                    "ocr_confidence": 0.95,
                    "mrz_valid": True,
                },
            },
            "mrz_valid": True,
            "ocr_confidence": 0.95,
            "issues": ["NAME_TOKEN_REPAIRED"],
            "schema_version": "1.0",
        },
    }
    respx.get(f"{UPSTREAM_BASE}/v1/sessions/ses_meta/result").mock(
        return_value=httpx.Response(200, json=upstream_body)
    )

    response = client.get("/reference/result/ses_meta")

    assert response.status_code == 200
    body = response.json()
    assert body["extraction_meta"] == upstream_body["extraction_meta"]


@respx.mock
def test_get_result_omits_extraction_meta_when_upstream_omits_it(
    client: TestClient,
) -> None:
    """When the platform omits extraction_meta (Bearer channel, or an old
    session with no merged canonical_document), the proxy must not fabricate
    the key — it stays absent, exactly as the upstream body dictates."""
    upstream_body = {
        "session_id": "ses_no_meta",
        "verdict": "APPROVED",
        "workflow": "document_and_liveness",
        "reference_id": "ref-no-meta",
    }
    respx.get(f"{UPSTREAM_BASE}/v1/sessions/ses_no_meta/result").mock(
        return_value=httpx.Response(200, json=upstream_body)
    )

    response = client.get("/reference/result/ses_no_meta")

    assert response.status_code == 200
    assert "extraction_meta" not in response.json()


@respx.mock
def test_get_result_proxies_404(client: TestClient) -> None:
    respx.get(f"{UPSTREAM_BASE}/v1/sessions/ses_missing/result").mock(
        return_value=httpx.Response(404, json={"detail": "session not found"})
    )

    response = client.get("/reference/result/ses_missing")

    assert response.status_code == 404
