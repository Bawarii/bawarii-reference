"""get_result retries 409 KEY_NOT_READY and a Retry-After 503."""

import os
import sys
import threading
import time

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from bawarii_client import BawariiClient  # noqa: E402
from main import app  # noqa: E402

BASE = "https://sandbox.api.bawarii.com"
RESULT = f"{BASE}/v1/sessions/ses_1/result"
OK = {"session_id": "ses_1", "status": "APPROVED"}


def _not_ready(retry_after: str | None = "7") -> httpx.Response:
    headers = (
        [(b"Retry-After", retry_after.encode("utf-8"))]
        if retry_after is not None
        else []
    )
    return httpx.Response(409, json={"code": "KEY_NOT_READY"}, headers=headers)


def _unavailable(retry_after: str | None = "4") -> httpx.Response:
    headers = {"Retry-After": retry_after} if retry_after is not None else {}
    return httpx.Response(503, json={"code": "SERVICE_UNAVAILABLE"}, headers=headers)


@pytest.fixture()
def sleeps() -> list[float]:
    return []


@pytest.fixture()
def bawarii(sleeps: list[float]) -> BawariiClient:
    return BawariiClient(BASE, "bk_test", sleep=sleeps.append)


@respx.mock
def test_key_not_ready_is_retried_then_succeeds(
    bawarii: BawariiClient, sleeps: list[float]
) -> None:
    route = respx.get(RESULT).mock(
        side_effect=[_not_ready("7"), httpx.Response(200, json=OK)]
    )
    assert bawarii.get_result("ses_1") == (200, OK)
    assert route.call_count == 2
    assert sleeps == [7]


@respx.mock
def test_key_not_ready_three_times_is_surfaced(
    bawarii: BawariiClient, sleeps: list[float]
) -> None:
    route = respx.get(RESULT).mock(return_value=_not_ready("100"))
    status, body = bawarii.get_result("ses_1")
    assert status == 409
    assert body["code"] == "KEY_NOT_READY"
    assert route.call_count == 3
    assert sleeps == [35, 35]


@respx.mock
def test_503_with_retry_after_is_retried_once_then_surfaced(
    bawarii: BawariiClient, sleeps: list[float]
) -> None:
    route = respx.get(RESULT).mock(return_value=_unavailable("90"))
    status, body = bawarii.get_result("ses_1")
    assert status == 503
    assert body["code"] == "SERVICE_UNAVAILABLE"
    assert route.call_count == 2
    assert sleeps == [35]


@respx.mock
def test_503_with_retry_after_then_success(
    bawarii: BawariiClient, sleeps: list[float]
) -> None:
    respx.get(RESULT).mock(
        side_effect=[_unavailable("4"), httpx.Response(200, json=OK)]
    )
    assert bawarii.get_result("ses_1") == (200, OK)
    assert sleeps == [4]


@respx.mock
def test_503_without_retry_after_is_not_retried(
    bawarii: BawariiClient, sleeps: list[float]
) -> None:
    route = respx.get(RESULT).mock(return_value=_unavailable(None))
    status, _ = bawarii.get_result("ses_1")
    assert status == 503
    assert route.call_count == 1
    assert sleeps == []


@respx.mock
def test_non_ascii_retry_after_uses_default(
    bawarii: BawariiClient, sleeps: list[float]
) -> None:
    respx.get(RESULT).mock(
        side_effect=[
            _not_ready("٣"),
            _unavailable_non_ascii(),
            httpx.Response(200, json=OK),
        ]
    )
    assert bawarii.get_result("ses_1") == (200, OK)
    assert sleeps == [5, 5]


def _unavailable_non_ascii() -> httpx.Response:
    return httpx.Response(
        503,
        json={"code": "SERVICE_UNAVAILABLE"},
        headers=[(b"Retry-After", "٣".encode("utf-8"))],
    )


@respx.mock
def test_other_409_code_is_not_retried(
    bawarii: BawariiClient, sleeps: list[float]
) -> None:
    route = respx.get(RESULT).mock(
        return_value=httpx.Response(409, json={"code": "SOMETHING_ELSE"})
    )
    status, _ = bawarii.get_result("ses_1")
    assert status == 409
    assert route.call_count == 1
    assert sleeps == []


@respx.mock
def test_slow_result_retry_does_not_block_other_requests() -> None:
    release = threading.Event()
    waiting = threading.Event()

    def blocking_sleep(_: float) -> None:
        waiting.set()
        release.wait(timeout=5)

    respx.get(RESULT).mock(side_effect=[_not_ready(), httpx.Response(200, json=OK)])
    result: dict = {}
    with TestClient(app) as c:
        app.state.bawarii_client = BawariiClient(BASE, "bk_test", sleep=blocking_sleep)

        def fetch() -> None:
            result["resp"] = c.get("/reference/result/ses_1")

        worker = threading.Thread(target=fetch)
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
