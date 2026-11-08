import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// An uppercase section eyebrow — `EXTRACTED IDENTITY`, `DOCUMENT SIDES`, etc.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.color = BawariiColors.ink70,
    this.padding = const EdgeInsets.only(left: 16, bottom: 8),
  });

  final String text;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: BawariiTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}
