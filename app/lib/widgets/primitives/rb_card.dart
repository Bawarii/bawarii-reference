import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// The flat, hairline-bordered card used throughout — `paper` fill,
/// `r20` corners, elevation 0, no shadow.
class RbCard extends StatelessWidget {
  const RbCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.tint,
    this.borderColor,
    this.borderRadius = BawariiRadii.r20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Color? borderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? BawariiColors.paper,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? BawariiColors.hairline),
      ),
      child: child,
    );
  }
}
