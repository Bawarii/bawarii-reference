import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../../theme/ref_colors.dart';

/// The High/Check/Review confidence distribution bar.
///
/// This is the one place `success` green is used for a confidence-related
/// indicator: read as a distribution, not a per-field judgement.
class ConfidenceDistributionBar extends StatelessWidget {
  const ConfidenceDistributionBar({
    super.key,
    required this.highCount,
    required this.checkCount,
    required this.reviewCount,
  });

  final int highCount;
  final int checkCount;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final segments = [
      (label: 'high', count: highCount, color: BawariiColors.success),
      (label: 'check', count: checkCount, color: RefColors.warningMid),
      (label: 'review', count: reviewCount, color: BawariiColors.warning),
    ].where((s) => s.count > 0).toList();

    final total = highCount + checkCount + reviewCount;
    // Every segment gets a flex floor so a single flagged field among many
    // stays visible rather than shrinking to an invisible sliver ('s
    // "clamped to 6dp" rule, approximated proportionally — Expanded flex has
    // no absolute pixel unit, so an exact 6dp floor isn't expressible
    // without risking overflow; a generous relative floor achieves the same
    // visual intent safely).
    const flexFloor = 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 10,
          child: total == 0
              ? null
              : Row(
                  children: [
                    for (var i = 0; i < segments.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: ((segments[i].count * 100) ~/ total).clamp(
                          flexFloor,
                          100,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: segments[i].color,
                            borderRadius: BorderRadius.circular(
                              BawariiRadii.r6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${s.count} ${s.label}',
                    style: BawariiTextStyles.fine.copyWith(
                      color: BawariiColors.ink70,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
