import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// The sticky bottom CTA zone: `bone` fill, an optional
/// hairline top border when content scrolls underneath, safe-area-aware
/// bottom padding.
class RbStickyBar extends StatelessWidget {
  const RbStickyBar({
    super.key,
    required this.children,
    this.bordered = false,
  });

  final List<Widget> children;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: BawariiColors.bone,
        border: bordered
            ? const Border(top: BorderSide(color: BawariiColors.hairline))
            : null,
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        bottomInset > 24 ? bottomInset : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}
