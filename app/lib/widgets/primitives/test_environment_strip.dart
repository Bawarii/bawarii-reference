import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// The persistent "TEST ENVIRONMENT" badge — required on S1–S5. Non-interactive.
class TestEnvironmentStrip extends StatelessWidget {
  const TestEnvironmentStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Test environment. All results are non-production.',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: BawariiColors.warningSoft,
            border: Border.all(color: BawariiColors.warning),
            borderRadius: BorderRadius.circular(BawariiRadii.r10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.science_outlined,
                size: 14,
                color: BawariiColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                'TEST ENVIRONMENT',
                style: BawariiTextStyles.fine.copyWith(
                  color: BawariiColors.warning,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.06 * 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
