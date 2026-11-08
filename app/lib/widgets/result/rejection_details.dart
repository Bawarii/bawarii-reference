import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../../models/rejection_copy.dart';
import '../../theme/ref_colors.dart';
import '../primitives/rb_card.dart';
import '../primitives/rb_chip.dart';
import '../primitives/section_label.dart';

/// RejectionDetails — REJECTED verdicts only.
class RejectionDetails extends StatelessWidget {
  const RejectionDetails({super.key, required this.reasonCodes});

  final List<String> reasonCodes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Why this was rejected', color: RefColors.errorInk),
        RbCard(
          child: reasonCodes.isEmpty
              ? Text(
                  'No specific reason was returned by the verification '
                  'engine.',
                  style: BawariiTextStyles.bodySmall.copyWith(
                    color: BawariiColors.ink70,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < reasonCodes.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _ReasonRow(code: reasonCodes[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final known = knownRejectionCodes.contains(code);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.remove_circle_outline,
          size: 16,
          color: BawariiColors.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: known
              ? Text(
                  rejectionMessage(code),
                  style: BawariiTextStyles.bodySmall.copyWith(
                    color: BawariiColors.ink,
                  ),
                )
              : RbChip(
                  label: code,
                  fill: BawariiColors.ink10,
                  textColor: BawariiColors.ink,
                  mono: true,
                  height: 24,
                ),
        ),
      ],
    );
  }
}
