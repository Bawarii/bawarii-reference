import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../../models/field_confidence_chip.dart';
import '../../models/issue_severity.dart';
import '../../theme/ref_colors.dart';
import '../../theme/ref_text_styles.dart';

/// A generic pill chip (the `Chip` primitive).
class RbChip extends StatelessWidget {
  const RbChip({
    super.key,
    required this.label,
    required this.fill,
    required this.textColor,
    this.icon,
    this.mono = false,
    this.height = 22,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final IconData? icon;
  final bool mono;
  final double height;

  @override
  Widget build(BuildContext context) {
    final textStyle = mono
        ? RefTextStyles.monoSmall.copyWith(fontSize: 12, color: textColor)
        : BawariiTextStyles.fine.copyWith(color: textColor);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
          color: fill, borderRadius: BorderRadius.circular(BawariiRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}

/// The five field-row confidence chips.
class ConfidenceChip extends StatelessWidget {
  const ConfidenceChip({super.key, required this.kind});

  final FieldConfidenceChipKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, fill, text, icon) = switch (kind) {
      FieldConfidenceChipKind.check => (
          'Check',
          BawariiColors.warningSoft,
          RefColors.warningInk,
          null,
        ),
      FieldConfidenceChipKind.review => (
          'Review',
          BawariiColors.warningSoft,
          RefColors.warningInk,
          Icons.flag_outlined,
        ),
      FieldConfidenceChipKind.repaired => (
          'Repaired',
          BawariiColors.trustSoft,
          BawariiColors.trust,
          Icons.auto_fix_high_outlined,
        ),
      FieldConfidenceChipKind.unmatched => (
          'Unmatched',
          BawariiColors.warningSoft,
          RefColors.warningInk,
          Icons.compare_arrows_outlined,
        ),
      FieldConfidenceChipKind.oneSide => (
          'One side only',
          BawariiColors.ink10,
          BawariiColors.ink70,
          null,
        ),
    };
    return RbChip(
      label: label,
      fill: fill,
      textColor: text,
      icon: icon,
    );
  }
}

/// Document-side acceptance status.
///
/// [notUsed] is distinct from [rejected]: it is shown for a
/// retake-class issue code (`SIDE_MISMATCH`, `MRZ_VIZ_MISMATCH`), where this
/// side's content was never evaluated at all, rather than evaluated and
/// found wanting. [rejected] stays reserved for a side whose own reported
/// status is genuinely `REJECTED`.
enum SideStatusKind { accepted, rejected, retaken, notCaptured, notUsed }

class SideStatusPill extends StatelessWidget {
  const SideStatusPill(
      {super.key, required this.status, required this.sideName});

  final SideStatusKind status;

  /// 'Front' or 'Back' — used only to name the side in the accessible label
  /// for [SideStatusKind.notUsed]; every other status
  /// renders unchanged.
  final String sideName;

  @override
  Widget build(BuildContext context) {
    final (label, fill, text, icon) = switch (status) {
      SideStatusKind.accepted => (
          'Accepted',
          BawariiColors.successSoft,
          RefColors.successInk,
          Icons.check,
        ),
      SideStatusKind.rejected => (
          'Rejected',
          BawariiColors.errorSoft,
          RefColors.errorInk,
          Icons.close,
        ),
      SideStatusKind.retaken => (
          'Retaken',
          BawariiColors.warningSoft,
          RefColors.warningInk,
          Icons.refresh,
        ),
      SideStatusKind.notCaptured => (
          'Not captured',
          BawariiColors.ink10,
          BawariiColors.ink70,
          null,
        ),
      // warning
      // tier, not Fatal red — the consequence to the *decision* is still
      // Fatal, but
      // this pill is read by a citizen, and amber reads as "needs
      // attention" rather than "you did something wrong", same register as
      // Retaken below (distinguished from it by word and icon, not colour).
      SideStatusKind.notUsed => (
          // AC7 path: the label is catalogue copy, never a
          // literal here — see uiCopy in models/issue_severity.dart.
          uiCopy['result.sides.notUsed']!,
          BawariiColors.warningSoft,
          RefColors.warningInk,
          Icons.remove_circle_outline,
        ),
    };
    final pill = RbChip(
      label: label,
      fill: fill,
      textColor: text,
      icon: icon,
      height: 24,
    );
    if (status != SideStatusKind.notUsed) return pill;

    // Copy key result.sides.notUsed: a screen reader
    // hears which side, not just "Not used" with no context; the icon
    // carries no meaning of its own and is excluded rather than announced.
    return Semantics(
      label: '$sideName side not used',
      excludeSemantics: true,
      child: pill,
    );
  }
}

/// A severity-classified extraction issue chip. Renders
/// the raw code in mono. [severity] is `null` for a code outside the
/// documented vocabulary — rendered neutrally rather than guessing a tier.
class IssueChip extends StatelessWidget {
  const IssueChip({super.key, required this.code, required this.severity});

  final String code;
  final IssueSeverity? severity;

  @override
  Widget build(BuildContext context) {
    final (fill, text, icon) = switch (severity) {
      IssueSeverity.advisory => (
          BawariiColors.trustSoft,
          BawariiColors.trust,
          Icons.info_outline,
        ),
      IssueSeverity.warning => (
          BawariiColors.warningSoft,
          RefColors.warningInk,
          Icons.warning_amber_rounded,
        ),
      IssueSeverity.fatal => (
          BawariiColors.errorSoft,
          RefColors.errorInk,
          Icons.error_outline,
        ),
      null => (BawariiColors.ink10, BawariiColors.ink70, null),
    };
    return RbChip(
      label: code,
      fill: fill,
      textColor: text,
      icon: icon,
      mono: true,
      height: 24,
    );
  }
}
