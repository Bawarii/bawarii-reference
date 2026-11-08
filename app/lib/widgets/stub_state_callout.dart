import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../theme/ref_colors.dart';

/// Shown when every value in `fields` is null/empty — a genuine extraction
/// failure, distinct from the capacity state. The copy
/// must not suggest retaking a photo: if the document is genuinely
/// unreadable, retaking will not help, and manual entry is the correct next
/// action.
class StubStateCallout extends StatelessWidget {
  const StubStateCallout({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BawariiColors.warningSoft,
        borderRadius: BorderRadius.all(Radius.circular(BawariiRadii.r10)),
        border: Border(
          left: BorderSide(color: BawariiColors.warning, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: BawariiColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Fields could not be extracted from this document — '
              'please enter details manually.',
              // : warningInk (the token rule), not ink70.
              style: BawariiTextStyles.bodySmall.copyWith(
                color: RefColors.warningInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
