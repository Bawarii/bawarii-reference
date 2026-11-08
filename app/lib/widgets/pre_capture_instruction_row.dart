import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// A single instruction step row shown on [PreCaptureScreen].
///
/// 40×40dp icon circle with trustSoft background, followed by instruction
/// text. Minimum row height is 56dp. The icon is decorative
/// (`ExcludeSemantics`) —: a per-icon label ("Camera capture
/// icon") produced redundant chatter ahead of the row's own text; the text
/// alone carries the meaning.
class PreCaptureInstructionRow extends StatelessWidget {
  const PreCaptureInstructionRow({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: BawariiColors.trustSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: BawariiColors.trust),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(text, style: BawariiTextStyles.body),
          ),
        ],
      ),
    );
  }
}
