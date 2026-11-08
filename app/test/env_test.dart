// BawariiKycEnvironment used to be hardcoded to sandbox in
// pre_capture_screen.dart. It's now derived from a --dart-define, defaulting
// to sandbox. bawariiEnvironmentFromName is the pure mapping this resolves
// through — extracted so it's testable without recompiling with a different
// dart-define.
import 'package:bawarii_kyc/bawarii_kyc.dart';
import 'package:bawarii_reference_app/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bawariiEnvironmentFromName', () {
    test('"production" resolves to BawariiKycEnvironment.production', () {
      expect(
        bawariiEnvironmentFromName('production'),
        BawariiKycEnvironment.production,
      );
    });

    test('"sandbox" resolves to BawariiKycEnvironment.sandbox', () {
      expect(
        bawariiEnvironmentFromName('sandbox'),
        BawariiKycEnvironment.sandbox,
      );
    });

    test(
      'anything else (typo, empty string, a staging-style value) fails '
      'safe to sandbox rather than production',
      () {
        expect(bawariiEnvironmentFromName(''), BawariiKycEnvironment.sandbox);
        expect(
          bawariiEnvironmentFromName('Production'),
          BawariiKycEnvironment.sandbox,
        );
        expect(
          bawariiEnvironmentFromName('staging'),
          BawariiKycEnvironment.sandbox,
        );
      },
    );
  });

  group('Env.bawariiEnvironment', () {
    test(
      'defaults to sandbox when BAWARII_ENVIRONMENT is not passed via '
      '--dart-define',
      () {
        expect(Env.bawariiEnvironmentName, 'sandbox');
        expect(Env.bawariiEnvironment, BawariiKycEnvironment.sandbox);
      },
    );
  });
}
