import 'package:bawarii_kyc/bawarii_kyc.dart';

/// Compile-time environment configuration.
///
/// Pass values via `--dart-define=REFERENCE_BACKEND_URL=http://10.0.2.2:8000`
/// when running on an Android emulator.
class Env {
  Env._();

  static const referenceBackendUrl = String.fromEnvironment(
    'REFERENCE_BACKEND_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Which Bawarii deployment this build's `HttpKycRepository` declares
  /// itself as — the raw dart-define value. See
  /// [bawariiEnvironment] for the resolved enum.
  static const bawariiEnvironmentName = String.fromEnvironment(
    'BAWARII_ENVIRONMENT',
    defaultValue: 'sandbox',
  );

  /// [bawariiEnvironmentName] resolved to a [BawariiKycEnvironment].
  static BawariiKycEnvironment get bawariiEnvironment =>
      bawariiEnvironmentFromName(bawariiEnvironmentName);
}

/// Resolves a raw `--dart-define=BAWARII_ENVIRONMENT=...` value to a
/// [BawariiKycEnvironment]. Anything other than the literal
/// string `"production"` (including the unset default, `"sandbox"`) resolves
/// to [BawariiKycEnvironment.sandbox] — fail safe, matching the SDK's own
/// declared-vs-reported mismatch check.
///
/// A top-level function rather than a private method on [Env] so this
/// mapping is unit-testable without needing to recompile with a different
/// dart-define.
BawariiKycEnvironment bawariiEnvironmentFromName(String name) =>
    name == 'production'
        ? BawariiKycEnvironment.production
        : BawariiKycEnvironment.sandbox;
