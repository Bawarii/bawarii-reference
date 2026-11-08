import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../../models/extraction_quality_summary.dart';
import '../../theme/ref_colors.dart';
import '../../theme/ref_text_styles.dart';
import '../primitives/rb_card.dart';
import 'confidence_distribution_bar.dart';

/// ExtractionQualityCard — lets a business stakeholder grasp extraction
/// quality in two seconds without reading a single field.
class ExtractionQualityCard extends StatelessWidget {
  const ExtractionQualityCard({
    super.key,
    required this.summary,
    this.onViewFlagged,
  });

  final ExtractionQualitySummary summary;

  /// Tapping the flagged-fields row scrolls to and pulses the
  /// first flagged field.
  final VoidCallback? onViewFlagged;

  @override
  Widget build(BuildContext context) {
    final mrzColor = switch (summary.mrzStatus) {
      'Valid' => RefColors.successInk,
      'Failed' => RefColors.errorInk,
      _ => RefColors.warningInk,
    };

    return RbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXTRACTION QUALITY',
            style: BawariiTextStyles.caption.copyWith(
              color: BawariiColors.ink70,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Metric('${summary.fieldsRead} of ${summary.fieldsTotal}', 'fields read'),
              _Metric(summary.mrzStatus, 'MRZ checksum', color: mrzColor),
              _Metric(summary.sidesStatus, 'sides accepted'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: BawariiColors.hairline),
          const SizedBox(height: 16),
          ConfidenceDistributionBar(
            highCount: summary.highCount,
            checkCount: summary.checkCount,
            reviewCount: summary.reviewCount,
          ),
          if (summary.flaggedCount > 0) ...[
            const SizedBox(height: 16),
            _FlaggedFieldsRow(count: summary.flaggedCount, onTap: onViewFlagged),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.caption, {this.color = BawariiColors.ink});

  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: RefTextStyles.metricValue.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: BawariiTextStyles.fine.copyWith(color: BawariiColors.ink70),
          ),
        ],
      ),
    );
  }
}

class _FlaggedFieldsRow extends StatelessWidget {
  const _FlaggedFieldsRow({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 field needs review' : '$count fields need review';
    return Material(
      color: BawariiColors.warningSoft,
      borderRadius: BorderRadius.circular(BawariiRadii.r10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: BawariiColors.warning),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.flag_outlined,
                        size: 16,
                        color: BawariiColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: BawariiTextStyles.bodySmall.copyWith(
                            color: RefColors.warningInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'View',
                        style: BawariiTextStyles.fine.copyWith(
                          color: RefColors.warningInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: RefColors.warningInk,
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
