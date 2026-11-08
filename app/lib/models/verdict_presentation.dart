import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../theme/ref_colors.dart';
import 'reference_workflow.dart';
import 'verdict.dart';

/// The verdict hero card's presentation for one [Verdict] (covers all seven API values).
final class VerdictPresentation {
  const VerdictPresentation({
    required this.label,
    required this.icon,
    required this.fill,
    required this.border,
    required this.ink,
    required this.meterColor,
    required this.defaultLevel,
    required String rationale,
    this.spin = false,
    String? rationaleDocumentOnly,
  }) : _rationale = rationale,
       _rationaleDocumentOnly = rationaleDocumentOnly;

  final String label;
  final IconData icon;
  final Color fill;
  final Color border;
  final Color ink;
  final Color meterColor;

  /// Fallback assurance level when the API response predates
  /// `assurance_level`.
  final int defaultLevel;
  final bool spin;

  final String _rationale;
  final String? _rationaleDocumentOnly;

  /// `APPROVED` reads differently for `document_only`.
  String rationaleFor(ReferenceWorkflow workflow) {
    if (workflow == ReferenceWorkflow.documentOnly &&
        _rationaleDocumentOnly != null) {
      return _rationaleDocumentOnly;
    }
    return _rationale;
  }
}

final Map<Verdict, VerdictPresentation> verdictPresentations = {
  Verdict.approved: const VerdictPresentation(
    label: 'APPROVED',
    icon: Icons.verified_outlined,
    fill: BawariiColors.successSoft,
    border: BawariiColors.success,
    ink: RefColors.successInk,
    meterColor: BawariiColors.success,
    defaultLevel: 2,
    rationale:
        'The e-Tazkira was authenticated and the person was confirmed as '
        'physically present.',
    rationaleDocumentOnly: 'The e-Tazkira document was authenticated.',
  ),
  Verdict.approvePending: const VerdictPresentation(
    label: 'APPROVED — PENDING CHECKS',
    icon: Icons.verified_user_outlined,
    fill: BawariiColors.successSoft,
    border: BawariiColors.success,
    ink: RefColors.successInk,
    meterColor: BawariiColors.success,
    defaultLevel: 1,
    rationale: 'Identity verified. Final platform checks are still completing.',
  ),
  Verdict.manualReview: const VerdictPresentation(
    label: 'IN MANUAL REVIEW',
    icon: Icons.hourglass_top_outlined,
    fill: BawariiColors.warningSoft,
    border: BawariiColors.warning,
    ink: RefColors.warningInk,
    meterColor: BawariiColors.warning,
    defaultLevel: 1,
    rationale:
        'A reviewer is checking this submission. This is normal when a '
        'field could not be read with confidence.',
  ),
  Verdict.rejected: const VerdictPresentation(
    label: 'REJECTED',
    icon: Icons.cancel_outlined,
    fill: BawariiColors.errorSoft,
    border: BawariiColors.error,
    ink: RefColors.errorInk,
    meterColor: BawariiColors.ink30,
    defaultLevel: 0,
    rationale: 'We could not verify this identity.',
  ),
  Verdict.processing: const VerdictPresentation(
    label: 'PROCESSING',
    icon: Icons.sync,
    fill: BawariiColors.trustSoft,
    border: BawariiColors.trust,
    ink: BawariiColors.trust,
    meterColor: BawariiColors.trust,
    defaultLevel: 0,
    spin: true,
    rationale: 'Verification is in progress.',
  ),
  // also used for an expired session (`rejection_reasons:
  // ["SESSION_EXPIRED"]`) — there is no dedicated "expired" presentation
  // yet (see the `_closedSessionReasons` doc comment in verdict.dart),
  // so this closed-session copy is reused as-is for both cases.
  Verdict.cancelled: const VerdictPresentation(
    label: 'CANCELLED',
    icon: Icons.block_outlined,
    fill: BawariiColors.ink10,
    border: BawariiColors.ink30,
    ink: BawariiColors.ink70,
    meterColor: BawariiColors.ink30,
    defaultLevel: 0,
    rationale: 'This verification was cancelled before it completed.',
  ),
  Verdict.unknown: const VerdictPresentation(
    label: 'UNKNOWN',
    icon: Icons.help_outline,
    fill: BawariiColors.ink10,
    border: BawariiColors.ink30,
    ink: BawariiColors.ink70,
    meterColor: BawariiColors.ink30,
    defaultLevel: 0,
    rationale: 'Verification status could not be determined.',
  ),
};

const Map<int, String> assuranceLevelCaptions = {
  0: 'Level 0 of 3 · Identity not established',
  1: 'Level 1 of 3 · Document only, with caveats',
  2: 'Level 2 of 3 · Document + biometric',
  3: 'Level 3 of 3 · Document + biometric + NFC chip',
};
