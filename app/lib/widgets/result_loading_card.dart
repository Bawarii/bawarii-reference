import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// Named loading stages driven by the polled verdict —
/// honest rather than decorative. This card (plus two skeleton blocks)
/// is the result screen's *first frame*, never a bare centred spinner.
enum ResultLoadStage { none, initiated, documentSubmitted, approvePending }

class ResultLoadingCard extends StatelessWidget {
  const ResultLoadingCard({
    super.key,
    this.stage = ResultLoadStage.none,
    this.secondsElapsed = 0,
  });

  final ResultLoadStage stage;
  final int secondsElapsed;

  @override
  Widget build(BuildContext context) {
    final (label, step, progress) = switch (stage) {
      ResultLoadStage.initiated => ('Uploading your document…', 'Step 1 of 3', 0.18),
      ResultLoadStage.documentSubmitted => ('Reading your document…', 'Step 2 of 3', 0.42),
      ResultLoadStage.approvePending => ('Finishing final checks…', 'Step 3 of 3', 0.78),
      ResultLoadStage.none => ('Analysing your submission…', null, 0.08),
    };

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BawariiColors.trustSoft,
        borderRadius: BorderRadius.circular(BawariiRadii.r20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(BawariiColors.trust),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: BawariiTextStyles.heading.copyWith(
                    color: BawariiColors.trust,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(BawariiRadii.r6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: BawariiColors.ink10,
              valueColor: const AlwaysStoppedAnimation(BawariiColors.trust),
            ),
          ),
          if (step != null) ...[
            const SizedBox(height: 8),
            Text(
              step,
              style: BawariiTextStyles.fine.copyWith(color: BawariiColors.ink70),
            ),
          ],
          if (secondsElapsed >= 25) ...[
            const SizedBox(height: 10),
            Text(
              'This is taking longer than usual. Your submission is safe.',
              style: BawariiTextStyles.bodySmall.copyWith(
                color: BawariiColors.ink70,
              ),
            ),
          ] else if (secondsElapsed >= 10) ...[
            const SizedBox(height: 10),
            Text(
              'Still processing — this may take a few more seconds.',
              style: BawariiTextStyles.bodySmall.copyWith(
                color: BawariiColors.ink70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
