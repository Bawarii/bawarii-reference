import json
import logging
import sys
from contextlib import asynccontextmanager
from typing import Any

import httpx
from fastapi import FastAPI, File, Form, HTTPException, Path, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response, StreamingResponse
from starlette.background import BackgroundTask
from pydantic import BaseModel

from bawarii_client import BawariiClient, SessionCreateTimeout, json_or_detail
from config import settings
from webhook_verifier import InvalidSignature, verify

# ─── Logging ─────────────────────────────────────────────────────────────────

logging.basicConfig(level=settings.LOG_LEVEL.upper())
logger = logging.getLogger(__name__)

# ─── Application lifecycle ───────────────────────────────────────────────────


@asynccontextmanager
async def lifespan(app: FastAPI):  # type: ignore[type-arg]
    _print_startup_banner()
    app.state.bawarii_client = BawariiClient(
        base_url=settings.BAWARII_API_BASE_URL,
        api_key=settings.BAWARII_API_KEY,
    )
    yield
    app.state.bawarii_client.close()


def _print_startup_banner() -> None:
    print(
        "\n"
        "================================================================\n"
        " Bawarii Reference Tenant Backend — DEV ONLY\n"
        " NOT FOR PUBLIC DEPLOYMENT\n"
        f" Listening on http://127.0.0.1:{settings.REFERENCE_BACKEND_PORT}\n"
        "================================================================\n",
        file=sys.stderr,
        flush=True,
    )


# ─── App + CORS ──────────────────────────────────────────────────────────────

app = FastAPI(title="Bawarii Reference Tenant Backend", lifespan=lifespan)

# DEV ONLY — wildcard CORS is unsafe in production. A real tenant MUST restrict
# allow_origins to its own front-end domain(s).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Request / response models ────────────────────────────────────────────────


class StartKycRequest(BaseModel):
    document_type: str
    reference_id: str
    workflow: str = "document_and_liveness"


# ─── Routes ──────────────────────────────────────────────────────────────────


def _upload_base_url(request: Request) -> str:
    """URL the SDK should use for document/biometric uploads.

    Points to this backend (which proxies to the Bawarii platform) so the SDK
    only needs one reachable host. For physical devices this must be the
    public ngrok URL; for simulators localhost works.
    """
    if settings.REFERENCE_BACKEND_PUBLIC_URL:
        return settings.REFERENCE_BACKEND_PUBLIC_URL.rstrip("/")
    # Fallback: derive from the incoming request's host (works for simulators).
    scheme = request.headers.get("x-forwarded-proto", request.url.scheme)
    host = request.headers.get("x-forwarded-host", request.url.netloc)
    return f"{scheme}://{host}"


# Plain `def` on purpose: the client is synchronous and may wait up to ~205 s
# (3 x 45 s + 2 x 35 s), so FastAPI must run it in the threadpool.
@app.post("/reference/start_kyc")
def start_kyc(body: StartKycRequest, request: Request) -> Any:
    client: BawariiClient = request.app.state.bawarii_client
    try:
        result = client.create_session(
            document_type=body.document_type,
            reference_id=body.reference_id,
            workflow=body.workflow,
        )
    except SessionCreateTimeout:
        # Never resend: no idempotency key, a resend can spend a second session.
        logger.error("Session create timed out; not resent")
        raise HTTPException(
            status_code=504,
            detail={
                "code": "SESSION_CREATE_TIMEOUT",
                "message": (
                    "Starting verification took too long. Please try again "
                    "later; a new session will be started."
                ),
            },
        )
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=exc.response.status_code,
            detail=json_or_detail(exc.response),
            headers=_forwarded_headers(exc.response, ("retry-after",)),
        )
    except httpx.HTTPError as exc:
        logger.error("Upstream request failed: %s", exc)
        raise HTTPException(status_code=502, detail="upstream unavailable")
    # Include the URL the SDK should use for uploads — proxied through this backend.
    result["upload_base_url"] = _upload_base_url(request)
    return result


# ─── SDK upload proxy ─────────────────────────────────────────────────────────
# The SDK cannot reach the Bawarii platform directly from a physical device.
# These routes forward document and biometric uploads verbatim.

PROXY_TIMEOUT = httpx.Timeout(45.0, connect=10.0)
SESSION_ID_PATTERN = r"^[A-Za-z0-9_-]{1,64}$"
SHA256_PATTERN = r"^[a-f0-9]{64}$"
# Upstream headers a caller needs to see: retry pacing, caching and integrity.
_PROXIED_HEADERS = (
    "retry-after",
    "etag",
    "content-length",
    "content-type",
    "x-content-sha256",
    "cache-control",
    "content-encoding",
)


def _forwarded_headers(
    resp: httpx.Response, names: tuple[str, ...] = _PROXIED_HEADERS
) -> dict[str, str]:
    return {n: resp.headers[n] for n in names if n in resp.headers}


async def _proxy_to_bawarii(
    method: str,
    path: str,
    auth_header: str | None,
    *,
    json_body: Any = None,
    multipart_data: dict | None = None,
    files: dict | None = None,
) -> Response:
    async with httpx.AsyncClient(
        base_url=settings.BAWARII_API_BASE_URL, timeout=PROXY_TIMEOUT
    ) as ac:
        headers = {}
        if auth_header:
            headers["Authorization"] = auth_header
        try:
            if multipart_data is not None:
                resp = await ac.request(method, path, headers=headers,
                                        data=multipart_data, files=files)
            else:
                resp = await ac.request(method, path, headers=headers, json=json_body)
        except httpx.HTTPError as exc:
            logger.error("Proxy request failed: %s", exc)
            raise HTTPException(status_code=502, detail="upstream unavailable")
    if not resp.content:
        return JSONResponse(
            status_code=resp.status_code,
            content={},
            headers=_forwarded_headers(resp, ("retry-after",)),
        )
    # Raw bytes, not re-encoded JSON: keeps non-JSON bodies and content-type.
    forwarded = _forwarded_headers(resp)
    forwarded.pop("content-length", None)
    return Response(content=resp.content, status_code=resp.status_code, headers=forwarded)


@app.post("/v1/sessions/{session_id}/documents")
async def proxy_document_upload(
    request: Request,
    session_id: str = Path(pattern=SESSION_ID_PATTERN),
    side: str = Form(...),
    doc_type: str = Form(...),
    document_image: UploadFile = File(...),
    document_image_hash: str = Form(...),
) -> Response:
    image_bytes = await document_image.read()
    return await _proxy_to_bawarii(
        "POST",
        f"/v1/sessions/{session_id}/documents",
        auth_header=request.headers.get("Authorization"),
        multipart_data={"side": side, "doc_type": doc_type, "document_image_hash": document_image_hash},
        files={"document_image": (document_image.filename, image_bytes, document_image.content_type)},
    )


@app.post("/v1/sessions/{session_id}/biometric")
async def proxy_biometric(
    request: Request, session_id: str = Path(pattern=SESSION_ID_PATTERN)
) -> Response:
    body = await request.json()
    return await _proxy_to_bawarii(
        "POST",
        f"/v1/sessions/{session_id}/biometric",
        auth_header=request.headers.get("Authorization"),
        json_body=body,
    )


@app.get("/v1/sessions/{session_id}/result")
async def proxy_result(
    request: Request, session_id: str = Path(pattern=SESSION_ID_PATTERN)
) -> Response:
    return await _proxy_to_bawarii(
        "GET",
        f"/v1/sessions/{session_id}/result",
        auth_header=request.headers.get("Authorization"),
    )


@app.get("/v1/sessions/{session_id}/prefill")
async def proxy_prefill(
    request: Request, session_id: str = Path(pattern=SESSION_ID_PATTERN)
) -> Response:
    """Pass-through: forwards the SDK's Bearer upload token to the Bawarii platform.

    The SDK calls this after document submission to retrieve unverified OCR
    field previews (BawariiPrefillData).  The reference backend never inspects
    the prefill payload — it proxies verbatim, including 403 PREFILL_NOT_ENABLED
    responses when the feature is disabled for a tenant.
    """
    return await _proxy_to_bawarii(
        "GET",
        f"/v1/sessions/{session_id}/prefill",
        auth_header=request.headers.get("Authorization"),
    )


@app.get("/v1/sdk/liveness-model/{sha256}")
async def proxy_liveness_model(
    request: Request, sha256: str = Path(pattern=SHA256_PATTERN)
) -> Response:
    """Streams the SDK's liveness model from the platform.

    Forwards the SDK's Bearer upload token and returns the upstream status
    with its pacing and integrity headers (Retry-After, ETag, Content-Length,
    Content-Type, X-Content-SHA256) unchanged.
    """
    ac = httpx.AsyncClient(
        base_url=settings.BAWARII_API_BASE_URL, timeout=PROXY_TIMEOUT
    )
    headers = {"Accept-Encoding": "identity"}
    auth_header = request.headers.get("Authorization")
    if auth_header:
        headers["Authorization"] = auth_header
    try:
        upstream = await ac.send(
            ac.build_request("GET", f"/v1/sdk/liveness-model/{sha256}", headers=headers),
            stream=True,
        )
    except httpx.HTTPError as exc:
        await ac.aclose()
        logger.error("Proxy request failed: %s", exc)
        raise HTTPException(status_code=502, detail="upstream unavailable")

    async def close() -> None:
        await upstream.aclose()
        await ac.aclose()

    return StreamingResponse(
        upstream.aiter_raw(),
        status_code=upstream.status_code,
        headers=_forwarded_headers(upstream),
        background=BackgroundTask(close),
    )


@app.get("/reference/result/{session_id}")
def get_result(
    request: Request, session_id: str = Path(pattern=SESSION_ID_PATTERN)
) -> Any:
    client: BawariiClient = request.app.state.bawarii_client
    try:
        resp = client.get_result_response(session_id)
    except httpx.HTTPError as exc:
        logger.error("Upstream request failed: %s", exc)
        raise HTTPException(status_code=502, detail="upstream unavailable")
    # Proxy the upstream status code and body verbatim.
    if resp.status_code >= 400:
        raise HTTPException(
            status_code=resp.status_code,
            detail=json_or_detail(resp),
            headers=_forwarded_headers(resp, ("retry-after",)),
        )
    try:
        return resp.json()
    except ValueError:
        raise HTTPException(status_code=502, detail="upstream returned a non-JSON response")


# The platform delivers at least once, and a session
# reviewed by an admin after its automatic decision yields a SECOND
# `verification.decision` event with its own event_id — so dedup must key
# on event_id, not session_id or decision. A plain in-memory set is fine
# for this reference app (single process, demo purposes only, reset on
# restart); a real integrator must persist seen event_ids durably (e.g. in
# its own database) and bounded (an unbounded in-memory set, like this one,
# grows forever in a long-lived process — a real store needs eviction, e.g.
# an LRU or a TTL) so dedup survives a restart and works across multiple
# backend instances.
_seen_event_ids: set[str] = set()


@app.post("/reference/webhook")
async def receive_webhook(request: Request) -> dict[str, bool]:
    # Read raw bytes BEFORE any JSON parsing so the signature covers the
    # exact bytes the sender transmitted.
    raw_body = await request.body()
    signature_header = request.headers.get("X-Bawarii-Signature")

    try:
        verify(
            signature_header=signature_header,
            raw_body=raw_body,
            secret=settings.BAWARII_WEBHOOK_SECRET,
        )
    except InvalidSignature as exc:
        logger.warning("Webhook signature invalid: %s", exc)
        raise HTTPException(status_code=401, detail=str(exc))

    event: dict[str, Any] = json.loads(raw_body)
    event_id = event.get("event_id")

    if event_id is not None and event_id in _seen_event_ids:
        logger.info(
            "Webhook received: event=%s session_id=%s event_id=%s (duplicate, skipped)",
            event.get("event"),
            event.get("session_id"),
            event_id,
        )
        return {"received": True}

    logger.info(
        "Webhook received: event=%s session_id=%s event_id=%s",
        event.get("event"),
        event.get("session_id"),
        event_id,
    )

    # Recorded only after the work above succeeds — a crash mid-processing
    # must leave event_id unmarked so the platform's at-least-once retry
    # reprocesses it, instead of the event being silently treated as already
    # handled when it never actually was.
    if event_id is not None:
        _seen_event_ids.add(event_id)

    return {"received": True}
