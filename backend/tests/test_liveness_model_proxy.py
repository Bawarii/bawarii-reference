"""Tests for GET /v1/sdk/liveness-model/{sha256} and proxy fidelity."""

import os
import sys

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from main import app  # noqa: E402

UPSTREAM_BASE = "https://sandbox.api.bawarii.com"
SHA = "a" * 64
MODEL_URL = f"{UPSTREAM_BASE}/v1/sdk/liveness-model/{SHA}"


@pytest.fixture()
def client() -> TestClient:
    with TestClient(app, raise_server_exceptions=True) as c:
        yield c


@respx.mock
def test_model_bytes_and_headers_are_passed_through(client: TestClient) -> None:
    payload = bytes(range(256)) * 4
    route = respx.get(MODEL_URL).mock(
        return_value=httpx.Response(
            200,
            content=payload,
            headers={
                "ETag": '"abc"',
                "Content-Type": "application/octet-stream",
                "X-Content-SHA256": SHA,
            },
        )
    )

    response = client.get(
        f"/v1/sdk/liveness-model/{SHA}",
        headers={"Authorization": "Bearer upload-token"},
    )

    assert response.status_code == 200
    assert response.content == payload
    assert response.headers["etag"] == '"abc"'
    assert response.headers["x-content-sha256"] == SHA
    assert response.headers["content-type"] == "application/octet-stream"
    assert response.headers["content-length"] == str(len(payload))
    assert route.calls.last.request.headers["authorization"] == "Bearer upload-token"


@respx.mock
def test_model_401_is_passed_through(client: TestClient) -> None:
    respx.get(MODEL_URL).mock(return_value=httpx.Response(401, json={"detail": "no"}))

    response = client.get(f"/v1/sdk/liveness-model/{SHA}")

    assert response.status_code == 401
    assert response.json() == {"detail": "no"}


@respx.mock
def test_model_429_keeps_retry_after(client: TestClient) -> None:
    respx.get(MODEL_URL).mock(
        return_value=httpx.Response(429, json={"detail": "slow"}, headers={"Retry-After": "7"})
    )

    response = client.get(f"/v1/sdk/liveness-model/{SHA}")

    assert response.status_code == 429
    assert response.headers["retry-after"] == "7"


@respx.mock
def test_model_404_is_passed_through(client: TestClient) -> None:
    respx.get(MODEL_URL).mock(return_value=httpx.Response(404, json={"detail": "gone"}))

    assert client.get(f"/v1/sdk/liveness-model/{SHA}").status_code == 404


@pytest.mark.parametrize("bad", ["abc", "A" * 64, "g" * 64, "a" * 63, "a" * 65])
def test_model_rejects_invalid_sha256(client: TestClient, bad: str) -> None:
    assert client.get(f"/v1/sdk/liveness-model/{bad}").status_code == 422


@respx.mock
def test_model_upstream_failure_is_502(client: TestClient) -> None:
    respx.get(MODEL_URL).mock(side_effect=httpx.ConnectError("down"))

    assert client.get(f"/v1/sdk/liveness-model/{SHA}").status_code == 502


@respx.mock
def test_proxy_keeps_non_json_body_and_content_type(client: TestClient) -> None:
    respx.get(f"{UPSTREAM_BASE}/v1/sessions/ses_1/result").mock(
        return_value=httpx.Response(
            502, content=b"<html>bad gateway</html>", headers={"Content-Type": "text/html"}
        )
    )

    response = client.get("/v1/sessions/ses_1/result")

    assert response.status_code == 502
    assert response.content == b"<html>bad gateway</html>"
    assert response.headers["content-type"].startswith("text/html")


@respx.mock
@pytest.mark.parametrize("status", [409, 429, 503])
def test_proxy_propagates_retry_after(client: TestClient, status: int) -> None:
    respx.get(f"{UPSTREAM_BASE}/v1/sessions/ses_1/prefill").mock(
        return_value=httpx.Response(status, json={"code": "X"}, headers={"Retry-After": "12"})
    )

    response = client.get("/v1/sessions/ses_1/prefill")

    assert response.status_code == status
    assert response.headers["retry-after"] == "12"


@respx.mock
@pytest.mark.parametrize("status", [409, 429, 503])
def test_reference_result_propagates_retry_after(client: TestClient, status: int) -> None:
    # 409 and 503 with Retry-After are retried by the client; use a no-sleep client.
    app.state.bawarii_client._sleep = lambda _s: None
    respx.get(f"{UPSTREAM_BASE}/v1/sessions/ses_1/result").mock(
        return_value=httpx.Response(status, json={"code": "OTHER"}, headers={"Retry-After": "3"})
    )

    response = client.get("/reference/result/ses_1")

    assert response.status_code == status
    assert response.headers["retry-after"] == "3"


@respx.mock
def test_reference_result_non_json_error_body(client: TestClient) -> None:
    respx.get(f"{UPSTREAM_BASE}/v1/sessions/ses_1/result").mock(
        return_value=httpx.Response(500, content=b"oops", headers={"Content-Type": "text/plain"})
    )

    response = client.get("/reference/result/ses_1")

    assert response.status_code == 500
    assert "non-JSON" in response.json()["detail"]["detail"]


def test_session_id_is_validated(client: TestClient) -> None:
    assert client.get("/reference/result/" + "x" * 65).status_code == 422
    assert client.get("/v1/sessions/bad.id/result").status_code == 422


@respx.mock
def test_model_forwards_cache_control_and_content_encoding(client: TestClient) -> None:
    respx.get(MODEL_URL).mock(
        return_value=httpx.Response(
            200,
            content=b"model",
            headers={"Cache-Control": "private, max-age=3600", "Content-Encoding": "identity"},
        )
    )

    response = client.get(f"/v1/sdk/liveness-model/{SHA}")

    assert response.headers["cache-control"] == "private, max-age=3600"
    assert response.headers["content-encoding"] == "identity"
