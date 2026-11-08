/// Local copy map from machine rejection codes to human-readable messages.
///
/// Rejection reasons from the API are machine codes, not human-readable
/// strings. This map provides the display text for known codes; unknown
/// codes fall back to showing the raw code value.
///
/// The map covers every documented `rejection_reasons` code, so a terminal
/// session (including a retake-class third refusal — SIDE_MISMATCH,
/// MRZ_VIZ_MISMATCH) could show a raw code chip instead of the explanation
/// a citizen needs. `rejection_reasons` is an open list, not a closed
/// vocabulary, so this is the set the app maps, not every code the service
/// could ever emit.
///
/// The two retake-class sentences follow the retake-class rules:
/// they say the session was closed after three attempts, name the last
/// attempt only, give the innocent cause, and end with the next action.
/// Neither names the MRZ, the number or the printed text, and neither says
/// "fake", "invalid" or "rejected". They differ from the per-side catalogue
/// sentences (`issue_severity.dart`) on purpose: those describe one side;
/// these describe why the whole session ended.
const Map<String, String> _rejectionCopyMap = {
  // result.rejection.sideMismatch
  'SIDE_MISMATCH':
      'This verification was closed after three photo attempts. In the '
          'last one, the front and back did not appear to come from the '
          'same card. Start a new verification and photograph both sides '
          'of one card.',
  // result.rejection.mrzVizMismatch
  'MRZ_VIZ_MISMATCH':
      'This verification was closed after three photo attempts. In the '
          'last one, the back of the card could not be checked from the '
          'photo. Start a new verification with the card flat, in good '
          'light and without glare. If it happens again, the card may be '
          'too worn to read; use a different identity document if you '
          'have one.',
  'LIVENESS_FAILED':
      'The selfie check did not confirm a live person. This can happen in '
          'poor lighting or if the camera was blocked.',
  // result.rejection.facialMatch — shared by both
  // FACIAL_MATCH_FAILED and FACIAL_MATCH_INSUFFICIENT (emitted
  // today), kept as two keys until the service and
  // this app agree on one name:
  // FACIAL_MATCH_INSUFFICIENT is a temporary alias — the service renames
  // it before 0.1.0, and stored decisions carrying the old name purge at
  // the 72h TTL — so this key is dropped in a later release, not now.
  'FACIAL_MATCH_FAILED':
      'The selfie could not be matched to the photo on the document. This '
          'can happen in poor lighting or when the document photo is worn.',
  'FACIAL_MATCH_INSUFFICIENT':
      'The selfie could not be matched to the photo on the document. This '
          'can happen in poor lighting or when the document photo is worn.',
  // result.rejection.documentTampered
  'DOCUMENT_TAMPERED':
      'The document did not pass the security checks, so it could not be '
          'accepted. If you think this is wrong, contact the organisation '
          'that asked you to verify.',
  // result.rejection.documentFlagged — generic on purpose: integrators
  // must not show this reason to the applicant, so the sentence
  // names no list and no check.
  'DOCUMENT_FLAGGED':
      'This document could not be accepted. If you think this is wrong, '
          'contact the organisation that asked you to verify.',
  // result.rejection.manualReview
  'MANUAL_REVIEW_REJECTED':
      'A reviewer checked this verification and could not approve it.',
  // result.rejection.sideDobMismatch
  'SIDE_DOB_MISMATCH':
      'The date of birth could not be matched between the front and back '
          'of the card, so this verification could not be approved.',
  // result.rejection.crossCheck
  'CROSS_CHECK_UNAVAILABLE':
      'The front and back could not be matched to each other '
          'automatically, so this verification could not be approved.',
  // result.rejection.sandboxRealDocument
  'SANDBOX_REAL_DOCUMENT_REJECTED':
      'The sandbox did not accept this document. Start a new verification.',
  // result.rejection.expired
  'SESSION_EXPIRED':
      'This verification expired before it completed. Start a new '
          'verification to try again.',
  // result.rejection.cancelled
  'SESSION_CANCELLED': 'This verification was cancelled before it completed.',
  'DOCUMENT_EXTRACTION_FAILED':
      'We could not read the required fields from the document images.',
  'VERIFICATION_INCONCLUSIVE':
      'Verification could not be completed with enough confidence to '
          'reach a decision.',
};

/// The codes [_rejectionCopyMap] has copy for — the single source of truth
/// for "known" vs. "falls back to a raw chip" (previously
/// duplicated as `RejectionDetails._knownCodes`, which is exactly how the
/// two lists went stale against each other).
final Set<String> knownRejectionCodes = _rejectionCopyMap.keys.toSet();

/// Returns the human-readable copy for a rejection code.
/// Falls back to the raw code when the code is not in the map.
String rejectionMessage(String code) => _rejectionCopyMap[code] ?? code;
