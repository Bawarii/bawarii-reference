import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// SystemBusyCallout — the `OCR_BUSY` capacity state,
/// "the single most important error-copy decision in this document": a 503
/// says nothing about the user's photograph, so this must never read as a
/// photo-quality complaint. `trustSoft` fill — informational, not error,
/// because nothing has failed.
///
/// Forbidden words enforced by construction (never present in this widget's
/// copy): retake, photo, image quality, blurry, could not read, failed.
class SystemBusyCallout extends StatelessWidget {
  const SystemBusyCallout({
    super.key,
    required this.secondsRemaining,
    required this.exhausted,
    required this.onTryNow,
  });

  final int secondsRemaining;
  final bool exhausted;
  final VoidCallback onTryNow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: BawariiColors.trustSoft,
          borderRadius: BorderRadius.circular(BawariiRadii.r20),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: BawariiColors.trust),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.hourglass_empty,
                            size: 24,
                            color: BawariiColors.trust,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Our service is at capacity',
                              style: BawariiTextStyles.heading.copyWith(
                                color: BawariiColors.trust,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your document was received and is safe. This is a '
                        'capacity limit on our side, not a problem with your '
                        'photo.',
                        style: BawariiTextStyles.bodySmall.copyWith(
                          color: BawariiColors.ink70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!exhausted) ...[
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  BawariiColors.trust,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              exhausted
                                  ? 'Automatic retries stopped.'
                                  : 'Retrying in ${secondsRemaining}s…',
                              style: BawariiTextStyles.fine.copyWith(
                                color: BawariiColors.ink70,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: onTryNow,
                            style: TextButton.styleFrom(
                              foregroundColor: BawariiColors.trust,
                            ),
                            child: const Text('Try now'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
