/// The three-tier extraction-issue severity model.
///
/// **The backend does not classify issue severity** — codes arrive as a flat
/// list. This classification is a *design* decision (not a backend
/// contract), chosen so a code's visual weight matches its actual
/// consequence for the decision.
///
/// **No fourth "retake" tier.** [retakeClassIssueCodes] map to [fatal]: the retake
/// is an interaction that happens in-flow on the SDK's own capture screen,
/// never redrawn here, so by the time a retake-class code reaches this
/// catalogue the side contributed nothing — the Fatal consequence.
enum IssueSeverity {
  /// The pipeline detected a problem and *resolved* it. Deliberately
  /// brand-navy, not amber — an advisory means the system worked.
  advisory,

  /// Fields were read, but two sources disagree or a value is invalid.
  warning,

  /// The side could not be processed at all, or was refused.
  fatal,
}

/// The complete issue vocabulary and its severity.
/// Codes not in this map are unclassified — see [severityOfIssue].
///
/// `SIDE_DOB_MISMATCH` is deliberately absent: dormant until front
/// DOB extraction exists, no catalogue entry by design.
const Map<String, IssueSeverity> issueSeverities = {
  'NAME_TOKEN_REPAIRED': IssueSeverity.advisory,
  'NAME_TOKEN_FILTERED': IssueSeverity.advisory,
  // The server
  // emits this on an accepted back side when the mark separating the
  // surname from the given names in the MRZ could not be read cleanly —
  // an advisory, same tier as NAME_TOKEN_REPAIRED, since the pipeline
  // resolved it rather than leaving the side unprocessed.
  'NAME_SEPARATOR_REPAIRED': IssueSeverity.advisory,
  'NAME_UNCORROBORATED': IssueSeverity.advisory,
  'MRZ_CHECK_DIGIT_FAILED': IssueSeverity.advisory,
  'NIN_NOT_FOUND': IssueSeverity.advisory,
  'NIN_VIZ_MISMATCH': IssueSeverity.warning,
  // Not a merge-level "MRZ vs VIZ disagree" warning: the merge never
  // emits this code. It is a per-side, retake-class
  // refusal (a checksum-valid back MRZ disagreeing with its own
  // corroborated VIZ), so it is Fatal like the other retake-class code,
  // SIDE_MISMATCH, below.
  'MRZ_VIZ_MISMATCH': IssueSeverity.fatal,
  'DOB_DATE_INVALID': IssueSeverity.warning,
  'EXPIRY_DATE_INVALID': IssueSeverity.warning,
  'MRZ_NOT_FOUND': IssueSeverity.fatal,
  'IMAGE_DECODE_ERROR': IssueSeverity.fatal,
  'IMAGE_TOO_LARGE': IssueSeverity.fatal,
  // The two document sides belong
  // to different cards. Retake-class, same tier as MRZ_VIZ_MISMATCH.
  'SIDE_MISMATCH': IssueSeverity.fatal,
  // Mixed-card detection.
  // Merged-level only, caps an APPROVED. Nothing was resolved, so
  // it is not advisory, and no side was refused, so it is not fatal.
  'CROSS_CHECK_UNAVAILABLE': IssueSeverity.warning,
};

/// Codes whose consequence is "this side was not used — retake it or use a
/// different card", not a content-level rejection of the side. Both are [IssueSeverity.fatal] (per side), but must never be
/// described to the user as a rejection — see `SideStatusKind.notUsed` in
/// `widgets/primitives/rb_chip.dart` and its use in
/// `widgets/result/document_sides_card.dart`.
const Set<String> retakeClassIssueCodes = {
  'MRZ_VIZ_MISMATCH',
  'SIDE_MISMATCH',
};

/// The plain-language client-facing translation for each known issue code,
/// in English — the source of truth. English is
/// final; see [issuePlainLanguageFa] and
/// [issuePlainLanguagePs] for the Dari/Pashto placeholders.
const Map<String, String> issuePlainLanguage = {
  'NAME_TOKEN_REPAIRED':
      'A name was reconstructed from the machine-readable zone after the '
          'printed text could not be read cleanly.',
  'NAME_TOKEN_FILTERED':
      'Part of the name text was discarded because it did not match a '
          'plausible name pattern.',
  'NAME_SEPARATOR_REPAIRED':
      'The surname and given names were separated automatically because '
          'the mark between them in the machine-readable zone could not be '
          'read cleanly.',
  'NAME_UNCORROBORATED':
      'The name was read from one side of the document only, so it could '
          'not be cross-checked.',
  'MRZ_CHECK_DIGIT_FAILED':
      'A candidate machine-readable line failed its check digit and was '
          'discarded. A valid line was used instead.',
  'NIN_NOT_FOUND':
      'No national identity number was found in the printed text on this '
          'side.',
  'NIN_VIZ_MISMATCH':
      'The identity number in the machine-readable zone does not match the '
          'number printed on the card.',
  // Replaces the stale "a field in the machine-readable zone disagrees with
  // the printed text" copy, which described a merge-level meaning that no
  // longer exists. Deliberately names neither the MRZ, the
  // number nor the printed text, and never says "fake", "invalid" or
  // "rejected" — the genuine cause (a misread,
  // tilted or worn back) is an innocent one.
  'MRZ_VIZ_MISMATCH':
      'This side was not used because it could not be checked from the '
          'photo. A new photo of the same card, flat and in good light, is '
          'needed.',
  'DOB_DATE_INVALID':
      'The date of birth read from the document is not a valid date.',
  'EXPIRY_DATE_INVALID':
      'The expiry date read from the document is not a valid date.',
  'MRZ_NOT_FOUND':
      'No machine-readable zone was found on this side, so it could not be '
          'processed.',
  'IMAGE_DECODE_ERROR': 'The uploaded image could not be decoded.',
  'IMAGE_TOO_LARGE':
      'The uploaded image was larger than the maximum accepted size.',
  // The genuine cause (a card picked up from the
  // wrong pair) differs from MRZ_VIZ_MISMATCH's, so the sentence differs on
  // purpose rather than sharing copy — a shared sentence would hide
  // nothing from a forger while giving the honest citizen worse advice.
  'SIDE_MISMATCH':
      'This side was not used because it does not match the other side of '
          'the card. Both sides must come from the same card.',
  // Merged-level, not per-side — the front and
  // back were each used, they just could not be linked to each other.
  'CROSS_CHECK_UNAVAILABLE':
      'The front and back could not be matched to each other automatically, '
          'so this result could not be approved without a person checking it.',
};

/// Dari (`fa`) placeholder copy for the codes added or recopied
/// for it. The reference app has no localisation
/// plumbing yet, so nothing reads this map at runtime — every
/// caller resolves copy through [plainLanguageForIssue], which is always
/// English. These entries exist so the translation gap is visible in the
/// one catalogue file rather than silently absent, and each falls back to
/// the English [issuePlainLanguage] copy verbatim until a native speaker
/// translates it.
///
/// TODO(l10n): translate — every value below is the English placeholder.
final Map<String, String> issuePlainLanguageFa = {
  'MRZ_VIZ_MISMATCH': issuePlainLanguage['MRZ_VIZ_MISMATCH']!,
  'SIDE_MISMATCH': issuePlainLanguage['SIDE_MISMATCH']!,
  'CROSS_CHECK_UNAVAILABLE': issuePlainLanguage['CROSS_CHECK_UNAVAILABLE']!,
  'NAME_SEPARATOR_REPAIRED': issuePlainLanguage['NAME_SEPARATOR_REPAIRED']!,
};

/// Pashto (`ps`) placeholder copy — see [issuePlainLanguageFa].
///
/// TODO(l10n): translate — every value below is the English placeholder.
final Map<String, String> issuePlainLanguagePs = Map.of(issuePlainLanguageFa);

/// UI copy addressed by a dotted key, for strings outside the per-issue-code
/// vocabulary above. Only the one key currently needed is defined — a full
/// copy-key table is a separate, larger localisation effort.
const Map<String, String> uiCopy = {
  // SideStatusPill's retake-class label.
  'result.sides.notUsed': 'Not used',
};

/// Dari (`fa`) placeholder for [uiCopy] — see [issuePlainLanguageFa] for why
/// this falls back to English verbatim.
///
/// TODO(l10n): translate — every value below is the English placeholder.
final Map<String, String> uiCopyFa = {
  'result.sides.notUsed': uiCopy['result.sides.notUsed']!,
};

/// Pashto (`ps`) placeholder for [uiCopy] — see [uiCopyFa].
///
/// TODO(l10n): translate — every value below is the English placeholder.
final Map<String, String> uiCopyPs = Map.of(uiCopyFa);

/// Returns the severity of [code], or `null` if [code] is not part of the
/// documented vocabulary. Callers should render an unmapped code as a raw,
/// unclassified value rather than guessing a severity for it.
IssueSeverity? severityOfIssue(String code) => issueSeverities[code];

/// Returns the plain-language translation of [code], or `null` if [code] is
/// not part of the documented vocabulary.
String? plainLanguageForIssue(String code) => issuePlainLanguage[code];
