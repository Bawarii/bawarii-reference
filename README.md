# Bawarii Reference Integration

This repository is the official B2B reference application for the Bawarii KYC
platform.  It shows exactly how a tenant integrates the `bawarii_kyc` SDK into
a Flutter mobile app backed by a lightweight server that holds the tenant's API
key.  The Flutter app never touches the API key — all platform calls flow
through the reference backend.

## Dependencies

The Flutter app depends on the `bawarii_kyc` package (the version is pinned in
`app/pubspec.yaml`) and on `bawarii_ui` for the shared design tokens. Both
packages come from pub.dev (`^0.1.0`, Developer Preview).

---

## Architecture

```
  ┌─────────────────────────────────────────┐
  │           Flutter (app/)                │
  │                                         │
  │  HomeScreen                             │
  │     └── PreCaptureScreen (SDK capture)  │
  │            ├── PrefillConfirmScreen     │
  │            └── ResultScreen             │
  │                                         │
  │  ReferenceBackendClient  ──────────────►│───► Reference Backend (backend/)
  │  BawariiKycPage / BawariiDocCaptureView │         │
  │           │ (SDK uploads go through     │         │ X-API-Key
  │           ▼  the reference backend)     │         ▼
  │      Reference Backend ─────────────────┼──► sandbox.api.bawarii.com
  └─────────────────────────────────────────┘
         (document and selfie uploads are proxied by the backend)

  Reference Backend (FastAPI)
  ┌──────────────────────────────────────────────┐
  │  POST /reference/start_kyc                   │  creates session, returns upload token
  │  GET  /reference/result/{session_id}         │  proxies verdict + PII to the app
  │  POST /reference/webhook                     │  verifies HMAC-SHA256 signature
  │  /v1/sessions/... and /v1/sdk/liveness-model │  SDK upload and model pass-through
  └──────────────────────────────────────────────┘
```

---

## Prerequisites

- Python 3.11+
- Flutter 3.19+ and Dart 3.3+
- A Bawarii sandbox API key and webhook secret, issued through the key flow in
  the developer portal
- `uv` Python package manager (`pip install uv`)

---

## Quickstart

**Step 1 — Configure**

```bash
cp .env.example .env
# Edit .env: set BAWARII_API_KEY and BAWARII_WEBHOOK_SECRET
```

**Step 2 — Run the backend**

```bash
cd backend

# Install uv (if you don't have it)
pip install uv

# uv creates an isolated environment from requirements.txt
uv run --with-requirements requirements.txt uvicorn main:app --reload --port 8000
```

The backend starts at `http://127.0.0.1:8000`.

Or run it with Docker instead (the port is published on loopback only):

```bash
cd backend
docker compose up --build
```

**Step 3 — Run the Flutter app**

```bash
cd app
flutter pub get
flutter run
```

On iOS, open `app/ios/Runner.xcworkspace` in Xcode once and choose your own
development team under Runner > Signing & Capabilities > Team. The project
does not ship with a team set.

---

## Tests

```bash
(cd backend && uv run --with-requirements requirements-dev.txt pytest)
(cd app && flutter test)
```

---

## Emulators and physical devices

The Android emulator cannot reach `localhost` on the host machine.  Use the
special alias `10.0.2.2` instead (cleartext HTTP to `10.0.2.2` and `localhost`
is allowed in debug builds only):

```bash
flutter run --dart-define=REFERENCE_BACKEND_URL=http://10.0.2.2:8000
```

The iOS simulator can use `http://127.0.0.1:8000`.

Physical devices cannot reach your machine's loopback address. Expose the
backend through an HTTPS tunnel, set `REFERENCE_BACKEND_PUBLIC_URL` in `.env`
to the tunnel URL, restart the backend, and pass the same URL to the app with
`--dart-define=REFERENCE_BACKEND_URL=https://<tunnel>`.

A tunnel makes every route public, including `/reference/start_kyc` (which
spends sessions on your key) and `/reference/result` (personal data). Protect
the tunnel (for example with the tunnel's basic-auth or IP allow-list), keep it
up only while testing, and rotate your key if the URL leaks.

---

## Declaring the environment (sandbox / production)

The Flutter app declares which Bawarii deployment its `HttpKycRepository`
talks to via a compile-time flag, defaulting to `sandbox`:

```bash
flutter run --dart-define=BAWARII_ENVIRONMENT=production
```

The SDK fails closed with a terminal, non-retried error if this doesn't
match the `environment` the server echoes back.

---

## Webhooks

The `/reference/webhook` endpoint verifies the `X-Bawarii-Signature` header
(HMAC-SHA256 over the raw body, with a freshness window) before processing any
event. The webhook URL and the signing secret are configured for your tenant
through the developer portal; see the portal's webhooks guide at
https://developer.bawarii.com/guides/webhooks/ once it is open. Put the secret
in `.env` as `BAWARII_WEBHOOK_SECRET`.

To receive real events during development, expose the backend through an HTTPS
tunnel and register `https://<tunnel>/reference/webhook` as your tenant's
webhook URL. The reference backend never sends a webhook URL when it creates a
session.

---

## What this sample does NOT do

The reference backend is intentionally minimal:

- It does not implement user authentication or session management.
- It does not store KYC results in a database.
- It does not handle retries or idempotency.
- It does not implement rate limiting.
- It is not designed for multi-tenant operation.
- `/reference/result` returns the verification result, including personal data,
  to any caller that can reach the backend on localhost. Never expose it.

A production integration must address all of the above.

---

## Troubleshooting

**`ValidationError: BAWARII_API_KEY` at startup**

You have not set the required environment variables.  Copy `.env.example` to
`.env` and fill in both `BAWARII_API_KEY` and `BAWARII_WEBHOOK_SECRET`.

**`flutter pub get` fails with "Could not find package bawarii_kyc"**

Check the `bawarii_kyc` and `bawarii_ui` entries in `app/pubspec.yaml` (both
`^0.1.0` from pub.dev) and that you have network access to pub.dev.

**Webhook signature validation fails with `stale`**

Your system clock is more than 5 minutes off from the Bawarii platform.
Synchronise your system time.

**Camera preview is black on Android emulator**

The Android emulator virtual camera has limited codec support.  Test camera
flows on a physical device.

---

## License

Apache-2.0 — see `LICENSE`.
