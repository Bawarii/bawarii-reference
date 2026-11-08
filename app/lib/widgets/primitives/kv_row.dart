import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../../theme/ref_text_styles.dart';

/// A label · value row for the developer info panel.
class KvRow extends StatelessWidget {
  const KvRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = true,
    this.last = false,
    this.valueWidget,
  });

  final String label;
  final String value;
  final bool mono;
  final bool last;

  /// When provided, replaces the plain-text value (e.g. a verdict chip).
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: BawariiColors.hairline),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 124),
            child: Text(
              label,
              style: BawariiTextStyles.fine.copyWith(
                color: BawariiColors.ink70,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  valueWidget ??
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    style: mono
                        ? RefTextStyles.monoSmall.copyWith(
                            color: BawariiColors.ink,
                          )
                        : BawariiTextStyles.bodySmall.copyWith(
                            color: BawariiColors.ink,
                          ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
