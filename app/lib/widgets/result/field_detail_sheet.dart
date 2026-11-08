import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../../models/confidence_tier.dart';
import '../../models/field_confidence_chip.dart';
import '../../models/identity_field_row.dart';
import '../../models/issue_severity.dart';
import '../../theme/ref_text_styles.dart';
import '../primitives/rb_chip.dart';
import '../primitives/rb_sheet.dart';

/// The Field Detail bottom sheet — "the most persuasive fifteen seconds of
/// the demo": confidence bar, read-from, cross-check, and
/// the plain-language "what we did" paragraph.
class FieldDetailSheet extends StatelessWidget {
  const FieldDetailSheet({super.key, required this.row});

  final IdentityFieldRow row;

  static Future<void> show(BuildContext context, IdentityFieldRow row) {
    return RbSheet.show<void>(
      context,
      label: row.label,
      child: FieldDetailSheet(row: row),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confidence = row.confidence;
    final tier = confidence == null ? null : tierOfConfidence(confidence);
    final provenance = row.provenance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            row.value,
            style: row.mono
                ? RefTextStyles.mono.copyWith(fontSize: 22)
                : BawariiTextStyles.title,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: BawariiColors.hairline),
        const SizedBox(height: 16),
        if (confidence != null && tier != null) ...[
          _Label('Confidence'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BawariiRadii.r6),
                  child: LinearProgressIndicator(
                    value: confidence.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: BawariiColors.ink10,
                    valueColor: AlwaysStoppedAnimation(
                      devConfidenceFillColorForTier(tier),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                confidence.toStringAsFixed(2),
                style: RefTextStyles.mono,
              ),
              if (tier != ConfidenceTier.high) ...[
                const SizedBox(width: 8),
                ConfidenceChip(
                  kind: tier == ConfidenceTier.review
                      ? FieldConfidenceChipKind.review
                      : FieldConfidenceChipKind.check,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (provenance != null) ...[
          _Label('Read from'),
          const SizedBox(height: 4),
          Text(provenance.readFrom, style: _body),
          const SizedBox(height: 16),
          _Label('Cross-check'),
          const SizedBox(height: 4),
          Text(provenance.crossCheck, style: _body),
          const SizedBox(height: 16),
          _Label('What we did'),
          const SizedBox(height: 4),
          Text(
            provenance.whatWeDid,
            style: BawariiTextStyles.body.copyWith(color: BawariiColors.ink),
          ),
        ] else
          Text(
            'This field predates confidence reporting, so no source detail '
            'is available for it.',
            style: _body,
          ),
        if (row.issues.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Label('Issues'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final code in row.issues)
                IssueChip(code: code, severity: severityOfIssue(code)),
            ],
          ),
        ],
      ],
    );
  }

  static TextStyle get _body =>
      BawariiTextStyles.bodySmall.copyWith(color: BawariiColors.ink);
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: BawariiTextStyles.caption.copyWith(color: BawariiColors.ink70),
    );
  }
}
