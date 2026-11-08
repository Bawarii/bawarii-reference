# Bawarii Reference Backend

Standalone FastAPI backend that demonstrates how a B2B tenant's server
communicates with the Bawarii platform API.  Run it locally while you
develop your Flutter integration.

## Quickstart

```bash
# Install uv (if you don't have it)
pip install uv

cp ../.env.example ../.env   # then fill in your keys

# Run the backend — uv creates an isolated environment from requirements.txt
uv run --with-requirements requirements.txt uvicorn main:app --reload --port 8000
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/reference/start_kyc` | Create a KYC session |
| GET | `/reference/result/{session_id}` | Fetch session result |
| POST | `/reference/webhook` | Receive signed webhook events |
| GET | `/v1/sdk/liveness-model/{sha256}` | SDK pass-through for the liveness model |

## Integrator notes: session create and `KEY_NOT_READY`

A new or rotated API key can take up to 30 seconds to work everywhere. On your server, set the client receive timeout for Bawarii API calls to 45 seconds, and if a call returns `409 KEY_NOT_READY`, wait for the number of seconds in its `Retry-After` header and send it again. Do not resend a session-create call that timed out: start a new session instead. The Bawarii SDK already uses 45 seconds for the calls it makes from the device.

`bawarii_client.py` follows this: `POST /v1/sessions` uses a 45 s read and 10 s connect timeout and is never resent after a timeout (the endpoint answers `504 SESSION_CREATE_TIMEOUT`). A `409` whose body `code` is `KEY_NOT_READY` is retried at most twice after `Retry-After` (integer seconds, capped at 35, 5 if missing), then returned to the app. Other `409` codes are untouched. Only session create uses 45 s: the other reference calls keep the client's 10 s default on purpose, because the server answers them at once with `409 KEY_NOT_READY` and `Retry-After` instead of holding them, while the sentence above recommends 45 s for your direct Bawarii API calls. `get_result` (`GET /v1/sessions/{id}/result`) retries `KEY_NOT_READY` the same way (at most twice, same request). It also retries once on a `503 SERVICE_UNAVAILABLE` that carries `Retry-After` (the server could not refresh its key list), waiting at most 35 s, and returns the `503` to the app if it persists; a `503` without `Retry-After` is not retried. `start_kyc` and `/reference/result/{id}` are plain `def` routes so the blocking client runs in FastAPI's threadpool; copy that, or use an async HTTP client.

## Tests

```bash
uv run --with-requirements requirements-dev.txt pytest
```
