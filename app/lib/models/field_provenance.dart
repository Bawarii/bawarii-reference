import 'confidence_tier.dart';

/// Derives the Field Detail Sheet's "Read from", "Cross-check", and
/// "What we did" copy for one of the six canonical
/// identity fields, from the *real* data the API actually returns:
/// confidence value + issue codes.
///
/// The design's demo `FIELDS` array (`ref-tokens.jsx`) hand-writes this copy
/// per specimen field, including per-field source detail the real API does
/// not expose (e.g. "machine-readable zone, line 3", and "confirmed against
/// the **front** side"). Two things make a verbatim port of that copy
/// dishonest for real data:
///
/// 1. The API's `extraction_meta` carries no per-field line-number or
///    zone-index attribution — only a confidence value and issue codes. This
///    module never fabricates a line number.
/// 2. The e-Tazkira's front side is Arabic-script only; on the
///    normal (MRZ-authoritative) path, all six canonical Latin fields here
///    are read from the back side's MACHINE-READABLE ZONE (the MRZ —
///    never the back side's printed VIZ text, which only ever serves as a
/// corroboration source). "Confirmed against the
///    other side" would therefore claim a front/back cross-check that
///    cannot happen for a Latin field. This module instead frames
///    corroboration as printed-text-vs-machine-readable-zone agreement —
///    "read from" is always the MRZ, "cross-check" is always against the
///    printed text — which is exactly what the real issue code
/// (`NIN_VIZ_MISMATCH`) already compares. (`MRZ_VIZ_MISMATCH` is
///    no longer a merge-level, per-field disagreement. It
///    is a per-side, retake-class refusal that never reaches a field's
///    `issues` list; see `models/issue_severity.dart`.)
///
/// Caveat: "never printed VIZ" is true for every
///    RENDERED case above except one rare degraded path — MRZ check
///    digits fail (`mrz_valid == false`) AND a front-VIZ national_id value
///    is what actually populated `national_id` (merge.py's
///    non-authoritative branch falls back to whichever side supplied a
///    field first). In that already-flagged/degraded state, the value
///    behind this label is printed-VIZ, not MRZ, even though the "machine-
///    readable zone" wording below doesn't change for it. This module does
///    not special-case that path today — the label describes the normal
///    MRZ-authoritative flow, not a per-render provenance guarantee.
///
/// Copy templates below are adapted "WHAT WE DID copy for
/// every confidence tier and issue combination" table, generalised from
/// specific example values to rules over (field key, tier, issues).
class FieldProvenance {
  const FieldProvenance({
    required this.readFrom,
    required this.crossCheck,
    required this.whatWeDid,
  });

  final String readFrom;
  final String crossCheck;
  final String whatWeDid;

  static const _mrzChecksumFields = {
    'national_id',
    'dob_gregorian',
    'date_of_expiry_gregorian',
  };
  static const _nameFields = {'surname_latin', 'given_name_latin'};

  // NIN_VIZ_MISMATCH only. MRZ_VIZ_MISMATCH no longer
  // reaches a field's issues (it is a per-side, retake-class refusal —
  // models/issue_severity.dart), and a broad `contains('MISMATCH')` would
  // also wrongly match the new per-side SIDE_MISMATCH code if it were ever
  // passed in here.
  static bool _isMismatch(String issue) => issue == 'NIN_VIZ_MISMATCH';

  /// Builds the provenance copy for [fieldKey] (a canonical field name such
  /// as `national_id` or `given_name_latin`) given its [confidence] and the
  /// [issues] attached to that specific field.
  factory FieldProvenance.derive({
    required String fieldKey,
    required double confidence,
    required List<String> issues,
    required String fieldLabel,
  }) {
    final tier = tierOfConfidence(confidence);
    final isChecksumField = _mrzChecksumFields.contains(fieldKey);
    final isNameField = _nameFields.contains(fieldKey);
    final mismatchCode = issues.where(_isMismatch).firstOrNull;

    if (issues.contains('NAME_TOKEN_REPAIRED')) {
      return FieldProvenance(
        readFrom: 'Back side · machine-readable zone (reconstructed)',
        crossCheck: 'Not corroborated against the printed text',
        whatWeDid:
            'The $fieldLabel could not be corroborated cleanly against the '
            'printed text, so it was reconstructed from the machine-readable '
            'zone. Because it could not be independently confirmed, it has '
            'been flagged for review.',
      );
    }

    // mismatchCode, when present, is always 'NIN_VIZ_MISMATCH' (the only
    // code _isMismatch matches) — see the note on `MRZ_VIZ_MISMATCH` above.
    if (mismatchCode != null) {
      return const FieldProvenance(
        readFrom: 'Back side · machine-readable zone',
        crossCheck: 'Disagrees with the printed text',
        whatWeDid: 'The identity number in the machine-readable zone does not '
            'match the number printed on the card. Both readings were '
            'kept, and the field has been flagged for review.',
      );
    }

    if (issues.contains('NAME_TOKEN_FILTERED')) {
      return FieldProvenance(
        readFrom: 'Back side · machine-readable zone (partially discarded)',
        crossCheck: 'Not independently corroborated',
        whatWeDid:
            'Part of the text in this field did not match a plausible name '
            'pattern and was discarded. What remains has been flagged for '
            'review.',
      );
    }

    if (isChecksumField && tier == ConfidenceTier.high) {
      return const FieldProvenance(
        readFrom: 'Back side · machine-readable zone',
        crossCheck: 'Confirmed by checksum',
        whatWeDid: 'This value is protected by a checksum in the document\'s '
            'machine-readable zone, and the checksum verified. It is a '
            'high-confidence read.',
      );
    }

    if (fieldKey == 'sex') {
      return const FieldProvenance(
        readFrom: 'Back side · machine-readable zone',
        crossCheck: 'No checksum available for this field',
        whatWeDid: 'This single-character field was read cleanly from the '
            'machine-readable zone but carries no checksum to confirm it '
            'against.',
      );
    }

    if (isNameField && tier == ConfidenceTier.high) {
      return const FieldProvenance(
        readFrom: 'Back side · machine-readable zone',
        crossCheck: 'Confirmed against the printed text',
        whatWeDid:
            'This name was read cleanly from the machine-readable zone and '
            'confirmed against the printed text. It is a high-confidence '
            'read.',
      );
    }

    if (issues.contains('NAME_UNCORROBORATED') ||
        tier == ConfidenceTier.check) {
      return const FieldProvenance(
        readFrom: 'Back side · machine-readable zone',
        crossCheck: 'Not independently corroborated',
        whatWeDid:
            'This value was read from the machine-readable zone but could '
            'not be cross-checked against the printed text.',
      );
    }

    return switch (tier) {
      ConfidenceTier.high => const FieldProvenance(
          readFrom: 'Back side · machine-readable zone',
          crossCheck: 'Confirmed against the printed text',
          whatWeDid: 'This is a high-confidence read.',
        ),
      ConfidenceTier.check => const FieldProvenance(
          readFrom: 'Back side · machine-readable zone',
          crossCheck: 'Not independently corroborated',
          whatWeDid:
              'This value was read with moderate confidence and has been '
              'flagged for a quick check.',
        ),
      ConfidenceTier.review => const FieldProvenance(
          readFrom: 'Back side · machine-readable zone',
          crossCheck: 'Not independently corroborated',
          whatWeDid:
              'This value could not be read with confidence and has been '
              'flagged for review.',
        ),
    };
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
