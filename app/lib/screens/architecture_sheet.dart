import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../widgets/primitives/rb_sheet.dart';

/// S6 — "How This Works" sheet.
///
/// Static bottom sheet explaining the Bawarii data-separation model.
/// No network calls, no dynamic data.
class ArchitectureSheet extends StatelessWidget {
  const ArchitectureSheet({super.key});

  /// Opens the architecture sheet as a modal bottom sheet.
  static void show(BuildContext context) {
    RbSheet.show<void>(
      context,
      title: 'How This Works',
      maxHeightFraction: 0.9,
      child: const ArchitectureSheet(),
    );
  }

  static const _steps = [
    (
      'Your app → your backend',
      '"Create session" — your backend holds your API key, calls the '
          'Bawarii API, and returns an upload token and session ID.',
    ),
    (
      'SDK → Bawarii platform',
      'The SDK captures the document and liveness video and uploads them '
          'directly, encrypted. It never sees your API key, and it never '
          'returns biometric data to your app.',
    ),
    (
      'Bawarii platform → your backend',
      'A webhook delivers the verdict and extracted fields, signed with '
          'HMAC-SHA256. Your backend verifies the signature.',
    ),
    (
      'Your app → your backend',
      '"Get result" — your backend returns the verdict and fields. Your '
          'API key never touches the app.',
    ),
    (
      'Extraction quality travels with the result',
      'Every field carries a confidence value, every document side carries '
          'its own status, and every repair the pipeline made is reported. '
          'You can route low-confidence results to manual review instead '
          'of accepting or rejecting blind.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'The data separation model',
          style: BawariiTextStyles.caption.copyWith(color: BawariiColors.ink70),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          Semantics(
            label: 'Step ${i + 1} of ${_steps.length}',
            child: _StepRow(
              step: i + 1,
              label: _steps[i].$1,
              sub: _steps[i].$2,
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text('What the SDK collects', style: BawariiTextStyles.heading),
        const SizedBox(height: 12),
        Text(
          'The Bawarii SDK captures front and back images of the Afghan '
          'e-Tazkira, and (in the Document + Liveness workflow) a short '
          'liveness video. These are encrypted on-device and uploaded '
          'directly to the Bawarii platform. The SDK does not retain '
          'biometric data on the device after upload. The host app does '
          'not receive biometric images at any point.',
          style: BawariiTextStyles.body.copyWith(color: BawariiColors.ink),
        ),
        const SizedBox(height: 24),
        Text(
          'What this reference backend does not do',
          style: BawariiTextStyles.heading,
        ),
        const SizedBox(height: 12),
        Text(
          'This reference backend is intentionally minimal. It does not '
          'authenticate users. It does not store verification results. It '
          'does not implement rate limiting. It is not designed for '
          'production use. See the README for what a production '
          'integration must add.',
          style: BawariiTextStyles.body.copyWith(color: BawariiColors.ink),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BawariiColors.trustSoft,
            borderRadius: BorderRadius.circular(BawariiRadii.r14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TEST ENVIRONMENT',
                style: BawariiTextStyles.caption.copyWith(
                  color: BawariiColors.trust,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This sample runs against a Bawarii test environment; '
                'sessions and results are non-production.',
                style: BawariiTextStyles.bodySmall.copyWith(
                  color: BawariiColors.ink70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.label, required this.sub});

  final int step;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: BawariiColors.trustSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: BawariiTextStyles.fine.copyWith(
              color: BawariiColors.trust,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: BawariiTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: BawariiColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: BawariiTextStyles.bodySmall.copyWith(
                  color: BawariiColors.ink70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
