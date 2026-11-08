import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// The modal bottom-sheet shell used for Field Detail and How This Works
/// : `paper`, `r28` top corners, drag handle,
/// label + title header row with a 44dp close affordance.
class RbSheet extends StatelessWidget {
  const RbSheet({
    super.key,
    required this.child,
    this.label,
    this.title,
    this.maxHeightFraction = 0.76,
    this.onClose,
  });

  final Widget child;
  final String? label;
  final String? title;
  final double maxHeightFraction;
  final VoidCallback? onClose;

  /// Shows [child] wrapped in the sheet shell as a modal bottom sheet.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? label,
    String? title,
    double maxHeightFraction = 0.76,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RbSheet(
        label: label,
        title: title,
        maxHeightFraction: maxHeightFraction,
        onClose: () => Navigator.of(ctx).pop(),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFraction;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: BawariiColors.paper,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BawariiRadii.r28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 2),
              child: _DragHandle(),
            ),
            if (label != null || title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (label != null)
                            Text(
                              label!.toUpperCase(),
                              style: BawariiTextStyles.caption.copyWith(
                                color: BawariiColors.ink70,
                              ),
                            ),
                          if (title != null)
                            Text(title!, style: BawariiTextStyles.title),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: BawariiColors.ink50,
                        ),
                        tooltip: 'Close',
                        onPressed: onClose,
                      ),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: child,
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: BawariiColors.ink10,
          borderRadius: BorderRadius.circular(BawariiRadii.pill),
        ),
      ),
    );
  }
}
