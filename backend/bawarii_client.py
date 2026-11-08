import time
from collections.abc import Callable
from typing import Any

import httpx

# Session create recommends a 45 s receive for direct
# Bawarii API calls. Only session create uses it here, because it can be held
# while a new key propagates. The other calls keep the 10 s client default on
# purpose: the server answers 409 KEY_NOT_READY / 503 with Retry-After instead
# of holding them, and they are retried below.
SESSION_CREATE_TIMEOUT = httpx.Timeout(45.0, connect=10.0)
KEY_NOT_READY_CODE = "KEY_NOT_READY"
KEY_NOT_READY_MAX_RETRIES = 2
RETRY_AFTER_CAP_SECONDS = 35
RETRY_AFTER_DEFAULT_SECONDS = 5
SERVICE_UNAVAILABLE_MAX_RETRIES = 1


class SessionCreateTimeout(Exception):
    """A POST /v1/sessions timed out. It must not be resent: there is no
    idempotency key, so a resend can create a second session against the
    daily budget."""


def json_or_detail(response: httpx.Response) -> Any:
    """The response body as JSON, or a ``detail`` string when it is not JSON
    (for example an HTML error page from an intermediary)."""
    try:
        return response.json()
    except ValueError:
        return {"detail": "upstream returned a non-JSON response"}


def _is_key_not_ready(response: httpx.Response) -> bool:
    if response.status_code != 409:
        return False
    try:
        body = response.json()
    except ValueError:
        return False
    return isinstance(body, dict) and body.get("code") == KEY_NOT_READY_CODE


def _is_retryable_unavailable(response: httpx.Response) -> bool:
    return response.status_code == 503 and "Retry-After" in response.headers


def _retry_after_seconds(response: httpx.Response) -> int:
    raw = response.headers.get("Retry-After", "").strip()
    if not (raw.isascii() and raw.isdigit()):
        return RETRY_AFTER_DEFAULT_SECONDS
    return min(int(raw), RETRY_AFTER_CAP_SECONDS)


class BawariiClient:
    """Thin synchronous HTTP client for the Bawarii platform API.

    One instance should be created at application startup and reused across
    requests.  The caller is responsible for handling ``httpx.HTTPError`` —
    this class does not swallow network failures.
    """

    def __init__(
        self,
        base_url: str,
        api_key: str,
        timeout: float | httpx.Timeout = httpx.Timeout(10.0),
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self._client = httpx.Client(
            base_url=base_url,
            headers={"X-API-Key": api_key},
            timeout=timeout,
        )
        self._sleep = sleep

    def _send_with_retry(
        self, send: Callable[[], httpx.Response], *, retry_unavailable: bool = False
    ) -> httpx.Response:
        """Run ``send``, waiting ``Retry-After`` and resending the same request on
        ``409 KEY_NOT_READY`` (up to twice) and, if enabled, once on a ``503``
        that carries ``Retry-After``. Returns the last response unraised."""
        not_ready_retries = 0
        unavailable_retries = 0
        while True:
            response = send()
            if (
                _is_key_not_ready(response)
                and not_ready_retries < KEY_NOT_READY_MAX_RETRIES
            ):
                not_ready_retries += 1
            elif (
                retry_unavailable
                and _is_retryable_unavailable(response)
                and unavailable_retries < SERVICE_UNAVAILABLE_MAX_RETRIES
            ):
                unavailable_retries += 1
            else:
                return response
            self._sleep(_retry_after_seconds(response))

    # ─── Public API ───────────────────────────────────────────────────────────────

    def create_session(
        self,
        *,
        document_type: str,
        reference_id: str,
        workflow: str = "document_and_liveness",
    ) -> dict:  # type: ignore[type-arg]
        """Create a new KYC session on the Bawarii platform.

        Returns the raw JSON body from the upstream response.
        Raises ``SessionCreateTimeout`` if the request timed out (never resent),
        ``httpx.HTTPStatusError`` on an error status (a ``409 KEY_NOT_READY`` is
        first retried up to twice after waiting ``Retry-After``), and
        ``httpx.HTTPError`` on other network or transport failure.
        """
        payload: dict[str, str] = {
            "document_type": document_type,
            "reference_id": reference_id,
            "workflow": workflow,
        }

        def send() -> httpx.Response:
            try:
                return self._client.post(
                    "/v1/sessions", json=payload, timeout=SESSION_CREATE_TIMEOUT
                )
            except httpx.TimeoutException as exc:
                raise SessionCreateTimeout() from exc

        response = self._send_with_retry(send)
        response.raise_for_status()
        try:
            return response.json()
        except ValueError as exc:
            raise httpx.DecodingError(
                "upstream returned a non-JSON response", request=response.request
            ) from exc

    def get_result_response(self, session_id: str) -> httpx.Response:
        """Fetch the current result, with the same retries as ``get_result``,
        and return the upstream response unparsed (headers included)."""
        return self._send_with_retry(
            lambda: self._client.get(f"/v1/sessions/{session_id}/result"),
            retry_unavailable=True,
        )

    def get_result(self, session_id: str) -> tuple[int, dict]:  # type: ignore[type-arg]
        """Fetch the current result for a session.

        Returns ``(status_code, json_body)`` verbatim so the reference backend
        can proxy the response without reinterpreting it. A ``409 KEY_NOT_READY``
        is retried up to twice and a ``503`` with ``Retry-After`` once, after
        waiting ``Retry-After``; the last response is then returned as is.
        Raises ``httpx.HTTPError`` on network failure.
        """
        response = self.get_result_response(session_id)
        return response.status_code, json_or_detail(response)

    def close(self) -> None:
        self._client.close()
