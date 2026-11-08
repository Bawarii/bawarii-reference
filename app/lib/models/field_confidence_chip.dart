import 'confidence_tier.dart';

/// The five field-row confidence chip kinds.
enum FieldConfidenceChipKind { review, unmatched, repaired, check, oneSide }

/// Resolves which chips to show on an identity-field row, in priority order,
/// capped at two: `Review` > `Unmatched` > `Repaired` > `Check` >
/// `One side only`. Faithful port of `chipsForField()` in
/// `ref-primitives.jsx`.
///
/// [issues] are the field-level issue codes attached to this specific field
/// (not the full per-side or merged issue lists).
List<FieldConfidenceChipKind> chipsForField({
  required double confidence,
  required List<String> issues,
}) {
  final tier = tierOfConfidence(confidence);
  final out = <FieldConfidenceChipKind>[];

  if (tier == ConfidenceTier.review) {
    out.add(FieldConfidenceChipKind.review);
  }
  // NIN_VIZ_MISMATCH only. the previous
  // `i.contains('MISMATCH')` substring match was already dead for
  // MRZ_VIZ_MISMATCH (it never reaches a field's issues — see
  // buildIdentityFieldRows.issuesFor) and would have wrongly matched the
  // new per-side SIDE_MISMATCH code too; matching the exact code removes
  // both risks.
  if (issues.contains('NIN_VIZ_MISMATCH')) {
    out.add(FieldConfidenceChipKind.unmatched);
  }
  if (issues.contains('NAME_TOKEN_REPAIRED')) {
    out.add(FieldConfidenceChipKind.repaired);
  }
  if (tier == ConfidenceTier.check) {
    out.add(FieldConfidenceChipKind.check);
  }
  if (issues.contains('NAME_UNCORROBORATED') && out.length < 2) {
    out.add(FieldConfidenceChipKind.oneSide);
  }

  return out.take(2).toList();
}
