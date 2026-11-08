# Bawarii Reference App

Flutter integration sample for the Bawarii KYC SDK.

## Running

```bash
flutter pub get
flutter run --dart-define=REFERENCE_BACKEND_URL=http://10.0.2.2:8000  # Android emulator
flutter run --dart-define=REFERENCE_BACKEND_URL=http://localhost:8000  # iOS simulator
```

Pass `--dart-define=BAWARII_ENVIRONMENT=production` to declare a production
`HttpKycRepository` instead of the default `sandbox` — the SDK
fails closed with a terminal, non-retried error if this doesn't match what
the server reports.

## Tests

```bash
flutter test
```

## Lint

```bash
flutter analyze
```
