"""session-create timeout and 409 KEY_NOT_READY handling."""

import os
import sys
import threading
import time

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from bawarii_client import BawariiClient, SessionCreateTimeout  # noqa: E402
from main import app  # noqa: E402

BASE = "https://sandbox.api.bawarii.com"
SESSIONS = f"{BASE}/v1/sessions"
OK = {"session_id": "ses_1", "upload_token": "tok", "expires_at": "x"}


def _not_ready(retry_after: str | None = "7") -> httpx.Response:
    headers = (
        [(b"Retry-After", retry_after.encode("utf-8"))]
        if retry_after is not None
        else []
    )
    return httpx.Response(
        409,
        json={"code": "KEY_NOT_READY", "message_key": "k", "request_id": "r1"},
        headers=headers,
    )


@pytest.fixture()
def sleeps() -> list[float]:
    return []


@pytest.fixture()
def bawarii(sleeps: list[float]) -> BawariiClient:
    return BawariiClient(BASE, "bk_test", sleep=sleeps.append)


def _create(client: BawariiClient) -> dict:
    return client.create_session(document_type="tazkira", reference_id="ref")


@respx.mock
def test_timeout_is_not_resent_and_raises_distinct_error(
    bawarii: BawariiClient,
) -> None:
    route = respx.post(SESSIONS).mock(side_effect=httpx.ReadTimeout("slow"))
    with pytest.raises(SessionCreateTimeout):
        _create(bawarii)
    assert route.call_count == 1


@respx.mock
def test_session_create_uses_45s_read_and_10s_connect_timeout(
    bawarii: BawariiClient,
) -> None:
    route = respx.post(SESSIONS).mock(return_value=httpx.Response(200, json=OK))
    _create(bawarii)
    timeout = route.calls[0].request.extensions["timeout"]
    assert timeout["read"] == 45.0
    assert timeout["connect"] == 10.0


@respx.mock
def test_key_not_ready_retried_twice_then_surfaced(
    bawarii: BawariiClient, sleeps: list[float]
) -> None:
    route = respx.post(SESSIONS).mock(
        side_effect=[_not_ready(), _not_ready(), _not_ready()]
    )
    with pytest.raises(httpx.HTTPStatusError) as err:
        _create(bawarii)
    assert err.value.response.status_code == 409
    assert route.call_count == 3
    assert sleeps == [7, 7]


@respx.mock
def test_key_not_ready_then_success_returns_session(bawarii: BawariiClient) -> None:
    route = respx.post(SESSIONS).mock(
        side_effect=[_not_ready("1"), httpx.Response(200, json=OK)]
    )
    assert _create(bawarii) == OK
    assert route.call_count == 2


@respx.mock
def test_retry_after_is_capped_at_35_seconds(
    bawarii: BawariiClient, sleeps: list[float]
) -> None:
    respx.post(SESSIONS).mock(
        side_effect=[_not_ready("120"), httpx.Response(200, json=OK)]
    )
    _create(bawarii)
    assert sleeps == [35]


@respx.mock
@pytest.mark.parametrize("header", [None, "soon", "²", "٣"])
def test_missing_or_non_integer_retry_after_defaults_to_5_seconds(
    bawarii: BawariiClient, sleeps: list[float], header: str | None
) -> None:
    respx.post(SESSIONS).mock(
        side_effect=[_not_ready(header), httpx.Response(200, json=OK)]
    )
    _create(bawarii)
    assert sleeps == [5]


@respx.mock
def test_other_409_codes_are_not_retried(
    bawarii: BawariiClient, sleeps: list[float]
) -> None:
    route = respx.post(SESSIONS).mock(
        return_value=httpx.Response(
            409, json={"code": "SOMETHING_ELSE"}, headers={"Retry-After": "3"}
        )
    )
    with pytest.raises(httpx.HTTPStatusError):
        _create(bawarii)
    assert route.call_count == 1
    assert sleeps == []


@respx.mock
def test_409_without_json_body_is_not_retried(bawarii: BawariiClient) -> None:
    route = respx.post(SESSIONS).mock(return_value=httpx.Response(409, text="conflict"))
    with pytest.raises(httpx.HTTPStatusError):
        _create(bawarii)
    assert route.call_count == 1


@respx.mock
def test_endpoint_returns_distinct_retry_later_error_on_timeout() -> None:
    route = respx.post(SESSIONS).mock(side_effect=httpx.ReadTimeout("slow"))
    with TestClient(app) as c:
        resp = c.post(
            "/reference/start_kyc",
            json={"document_type": "tazkira", "reference_id": "ref"},
        )
    assert resp.status_code == 504
    assert resp.json()["detail"]["code"] == "SESSION_CREATE_TIMEOUT"
    assert "bk_" not in resp.text
    assert route.call_count == 1


@respx.mock
def test_slow_create_does_not_block_other_requests() -> None:
    release = threading.Event()
    waiting = threading.Event()

    def blocking_sleep(_: float) -> None:
        waiting.set()
        release.wait(timeout=5)

    respx.post(SESSIONS).mock(side_effect=[_not_ready(), httpx.Response(200, json=OK)])
    result: dict = {}
    with TestClient(app) as c:
        app.state.bawarii_client = BawariiClient(BASE, "bk_test", sleep=blocking_sleep)

        def start() -> None:
            result["resp"] = c.post(
                "/reference/start_kyc",
                json={"document_type": "tazkira", "reference_id": "ref"},
            )

        worker = threading.Thread(target=start)
        worker.start()
        assert waiting.wait(timeout=2)
        started = time.monotonic()
        other = c.get("/openapi.json")
        elapsed = time.monotonic() - started
        release.set()
        worker.join(timeout=5)

    assert other.status_code == 200
    assert elapsed < 1.0
    assert result["resp"].status_code == 200
