import 'package:flutter/material.dart';

import '../../models/identity_field_row.dart';
import '../primitives/rb_card.dart';
import '../primitives/section_label.dart';
import 'identity_field_row_tile.dart';

/// The "Extracted identity" card — a stack of [IdentityFieldRowTile]s.
class IdentityFieldsCard extends StatelessWidget {
  const IdentityFieldsCard({
    super.key,
    required this.rows,
    required this.revealNationalId,
    required this.onToggleRevealNationalId,
    required this.onTapField,
  });

  final List<IdentityFieldRow> rows;
  final bool revealNationalId;
  final VoidCallback onToggleRevealNationalId;
  final ValueChanged<IdentityFieldRow> onTapField;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Extracted identity'),
        RbCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                IdentityFieldRowTile(
                  row: rows[i],
                  isLast: i == rows.length - 1,
                  revealed: rows[i].mask && revealNationalId,
                  onToggleReveal: onToggleRevealNationalId,
                  onTap: () => onTapField(rows[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
