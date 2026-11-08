import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/ref_text_styles.dart';

/// A mono value row with a 44dp copy affordance.
/// Used for Session ID / Reference ID in the developer panel.
class MonoRow extends StatelessWidget {
  const MonoRow({
    super.key,
    required this.label,
    required this.value,
    this.copyable = true,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: BawariiTextStyles.fine.copyWith(color: BawariiColors.ink70),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    value,
                    style: RefTextStyles.monoSmall.copyWith(
                      color: BawariiColors.ink,
                    ),
                  ),
                ),
              ),
              if (copyable)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    icon: const Icon(
                      Icons.copy_outlined,
                      size: 16,
                      color: BawariiColors.ink50,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Copy $label',
                    onPressed: () => _copy(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 2)),
      );
    }
  }
}
