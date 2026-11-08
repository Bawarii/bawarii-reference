import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../../models/confidence_tier.dart';
import '../../models/field_confidence_chip.dart';
import '../../models/identity_field_row.dart';
import '../../theme/ref_text_styles.dart';
import '../primitives/rb_chip.dart';

/// One row of the "Extracted identity" card.
///
/// A 4dp leading confidence rail, label + value, up to two priority-ordered
/// confidence chips, a mask/reveal toggle (National ID) or a chevron
/// (everything else — "every field is inspectable, not just flagged ones"),
/// and a tap target that opens the Field Detail sheet.
class IdentityFieldRowTile extends StatelessWidget {
  const IdentityFieldRowTile({
    super.key,
    required this.row,
    required this.revealed,
    required this.onToggleReveal,
    required this.onTap,
    this.isLast = false,
  });

  final IdentityFieldRow row;
  final bool revealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final confidence = row.confidence;
    final tier = confidence == null ? null : tierOfConfidence(confidence);
    final chips = confidence == null
        ? const <FieldConfidenceChipKind>[]
        : chipsForField(confidence: confidence, issues: row.issues);

    final displayValue = row.mask && !revealed
        ? '•••••••••• ${row.value.length >= 4 ? row.value.substring(row.value.length - 4) : row.value}'
        : row.value;

    final tierLabel = switch (tier) {
      ConfidenceTier.review => ', flagged for review',
      ConfidenceTier.check => ', flagged for a quick check',
      ConfidenceTier.high || null => '',
    };

    return Semantics(
      label: '${row.label}, $displayValue$tierLabel',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Container(
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: BawariiColors.hairline),
                      ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      color: tier == null
                          ? Colors.transparent
                          : railColorForTier(tier),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text(
                                  row.label.toUpperCase(),
                                  style: BawariiTextStyles.fine.copyWith(
                                    color: BawariiColors.ink70,
                                    letterSpacing: 0.08 * 12,
                                  ),
                                ),
                                const Spacer(),
                                for (final kind in chips) ...[
                                  const SizedBox(width: 6),
                                  ConfidenceChip(kind: kind),
                                ],
                                if (row.mask) ...[
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        revealed
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 18,
                                        color: BawariiColors.ink50,
                                      ),
                                      tooltip: revealed ? 'Hide' : 'Reveal',
                                      onPressed: onToggleReveal,
                                    ),
                                  ),
                                ] else
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(
                                      Icons.chevron_right,
                                      size: 14,
                                      color: BawariiColors.ink30,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                displayValue,
                                style: row.mono
                                    ? RefTextStyles.mono
                                    : BawariiTextStyles.heading,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
