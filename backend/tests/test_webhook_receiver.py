"""Tests for POST /reference/webhook (the FastAPI receiver itself).

tests/test_webhook.py covers webhook_verifier.verify() directly. This file
covers the receiver route: that a validly-signed delivery is accepted,
that it logs the real `event` field (bodies carry
`event`, never `event_type`), and that it dedupes on `event_id` — a
session reviewed by an admin after its automatic decision yields a SECOND
`verification.decision` event with its own event_id,
and the platform delivers at least once besides, so the same event_id can
arrive more than once.
"""

import hashlib
import hmac
import json
import logging
import os
import sys
import time

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("BAWARII_API_KEY", "bk_test_abc123")
os.environ.setdefault("BAWARII_WEBHOOK_SECRET", "test-webhook-secret")

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

import main  # noqa: E402
from main import app  # noqa: E402

SECRET = os.environ["BAWARII_WEBHOOK_SECRET"]


@pytest.fixture()
def client() -> TestClient:
    with TestClient(app, raise_server_exceptions=True) as c:
        yield c


@pytest.fixture(autouse=True)
def _reset_seen_event_ids():
    """The dedup set is module-level state — isolate each test from
    whatever an earlier test in this session already saw."""
    main._seen_event_ids.clear()
    yield
    main._seen_event_ids.clear()


def _sign(body: bytes, secret: str = SECRET) -> str:
    timestamp = int(time.time())
    signed_payload = f"{timestamp}.".encode("ascii") + body
    digest = hmac.new(secret.encode("ascii"), signed_payload, hashlib.sha256).hexdigest()
    return f"t={timestamp},sha256={digest}"


def _event_body(**overrides) -> bytes:
    event = {
        "event": "verification.decision",
        "event_id": "evt_" + "1" * 32,
        "session_id": "sess-1",
        "tenant_id": "tnt-1",
        "decision": "APPROVED",
        "checks": {"face_match": {"status": "not_performed", "reason": "not_enabled"}},
    }
    event.update(overrides)
    return json.dumps(event, separators=(",", ":")).encode()


class TestReceiveWebhookAcceptsValidSignature:
    def test_valid_signature_returns_received_true(self, client: TestClient) -> None:
        body = _event_body()
        response = client.post(
            "/reference/webhook",
            content=body,
            headers={"X-Bawarii-Signature": _sign(body)},
        )
        assert response.status_code == 200
        assert response.json() == {"received": True}

    def test_invalid_signature_returns_401(self, client: TestClient) -> None:
        body = _event_body()
        response = client.post(
            "/reference/webhook",
            content=body,
            headers={"X-Bawarii-Signature": "t=1,sha256=" + "0" * 64},
        )
        assert response.status_code == 401


class TestReceiveWebhookLogsTheEventField:
    """The delivered body's key is `event`, never
    `event_type` — main.py used to log the wrong (always-None) field."""

    def test_logs_event_not_event_type(self, client: TestClient, caplog) -> None:
        body = _event_body(event="verification.decision")
        with caplog.at_level(logging.INFO, logger="main"):
            response = client.post(
                "/reference/webhook",
                content=body,
                headers={"X-Bawarii-Signature": _sign(body)},
            )
        assert response.status_code == 200
        messages = [r.getMessage() for r in caplog.records]
        assert any("event=verification.decision" in m for m in messages)
        assert not any("event=None" in m for m in messages)


class TestReceiveWebhookDedupesOnEventId:
    def test_duplicate_event_id_is_logged_as_duplicate(self, client: TestClient, caplog) -> None:
        body = _event_body(event_id="evt_" + "2" * 32)

        with caplog.at_level(logging.INFO, logger="main"):
            first = client.post(
                "/reference/webhook",
                content=body,
                headers={"X-Bawarii-Signature": _sign(body)},
            )
            second = client.post(
                "/reference/webhook",
                content=body,
                headers={"X-Bawarii-Signature": _sign(body)},
            )

        assert first.status_code == 200
        assert second.status_code == 200
        messages = [r.getMessage() for r in caplog.records]
        assert any("duplicate" in m for m in messages)

    def test_different_event_ids_for_the_same_session_are_not_deduped(
        self, client: TestClient, caplog
    ) -> None:
        """A reviewed session yields exactly two
        verification.decision events (the automatic REQUIRES_MANUAL_REVIEW,
        then the manual APPROVED/REJECTED) — each with its own event_id,
        so neither is dropped as a duplicate of the other."""
        first_body = _event_body(
            event_id="evt_" + "3" * 32, decision="REQUIRES_MANUAL_REVIEW"
        )
        second_body = _event_body(event_id="evt_" + "4" * 32, decision="APPROVED")

        with caplog.at_level(logging.INFO, logger="main"):
            first = client.post(
                "/reference/webhook",
                content=first_body,
                headers={"X-Bawarii-Signature": _sign(first_body)},
            )
            second = client.post(
                "/reference/webhook",
                content=second_body,
                headers={"X-Bawarii-Signature": _sign(second_body)},
            )

        assert first.status_code == 200
        assert second.status_code == 200
        messages = [r.getMessage() for r in caplog.records]
        assert not any("duplicate" in m for m in messages)

    def test_missing_event_id_never_deduped(self, client: TestClient) -> None:
        """A legacy-shaped body with no event_id at all must not crash the
        dedup check, and is never treated as a duplicate of anything."""
        body = _event_body()
        del_body = json.loads(body)
        del del_body["event_id"]
        body = json.dumps(del_body, separators=(",", ":")).encode()

        first = client.post(
            "/reference/webhook",
            content=body,
            headers={"X-Bawarii-Signature": _sign(body)},
        )
        second = client.post(
            "/reference/webhook",
            content=body,
            headers={"X-Bawarii-Signature": _sign(body)},
        )
        assert first.status_code == 200
        assert second.status_code == 200
