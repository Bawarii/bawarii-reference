/// Verdict states returned by the Bawarii platform.
///
/// `GET /result` `verdict` is now
/// always one of `APPROVED | REJECTED | REQUIRES_MANUAL_REVIEW | PENDING`.
/// `PENDING` is the *only* non-terminal value the
/// server emits. A cancelled or expired session is no longer a distinct
/// wire value either: both now arrive as `REJECTED` with a
/// `rejection_reasons` entry (`SESSION_CANCELLED` / `SESSION_EXPIRED`)
/// that [verdictFromApi] inspects to recover the [cancelled]
/// presentation.
///
/// the API previously emitted seven
/// verdict strings; this enum previously collapsed two of them into
/// [unknown] — `APPROVE_PENDING` (a *positive* in-review state) rendered
/// identically to a status that "could not be determined", and `CANCELLED`
/// was likewise indistinguishable from unknown. [approvePending] and
/// [cancelled] were the two new members the spec called for.
///
/// `APPROVE_PENDING` no longer appears on the wire — the server
/// now emits `REQUIRES_MANUAL_REVIEW` for that case too, so the positive
/// styling for [approvePending] is no longer reachable from a live
/// server. The member and its mapping are kept for one
/// release as a legacy/defensive tolerance only.
enum Verdict {
  approved,
  approvePending,
  rejected,
  manualReview,
  processing,
  cancelled,
  unknown;
}

/// `rejection_reasons` codes that mean a `REJECTED`
/// verdict is actually a closed session — cancelled or expired — rather
/// than an ordinary rejection, and should render with the existing
/// [Verdict.cancelled] presentation instead of [Verdict.rejected].
///
/// Note: there is no dedicated presentation for an *expired* session.
/// `SESSION_EXPIRED` reuses the existing `CANCELLED` label/presentation
/// (the closed-session treatment) rather than a new `Verdict.expired`,
/// since no such presentation exists yet. If expired sessions need their
/// own copy, add a `Verdict.expired` member plus a `verdictPresentations`
/// entry and route `SESSION_EXPIRED` to it instead of here.
const _closedSessionReasons = {'SESSION_CANCELLED', 'SESSION_EXPIRED'};

/// Maps an API verdict string (plus `rejection_reasons`, when available) to
/// a [Verdict] enum value.
///
/// Mapping:
///   APPROVED                                                  → [Verdict.approved]
///   REJECTED + rejection_reasons has SESSION_CANCELLED/_EXPIRED → [Verdict.cancelled]
///   REJECTED (any other reason, or none)                      → [Verdict.rejected]
///   REQUIRES_MANUAL_REVIEW                                    → [Verdict.manualReview]
///   PENDING                                                   → [Verdict.processing]
///   everything else                                           → [Verdict.unknown]
///
/// Legacy tolerance, kept for one release in case an older server
/// deployment is still emitting legacy values:
///   PROCESSING | INITIATED | DOCUMENT_SUBMITTED | BIOMETRIC_SUBMITTED
///                            → [Verdict.processing]
///   APPROVE_PENDING          → [Verdict.approvePending]  (no longer reachable)
///   CANCELLED                → [Verdict.cancelled]
///
/// [rejectionReasons] is only visible over the X-API-Key channel — this
/// app's backend proxies with X-API-Key, so it is always available here —
/// a Bearer-channel caller never sees it and cannot distinguish a cancelled
/// or expired session from an ordinary rejection.
Verdict verdictFromApi(String? raw, {List<String> rejectionReasons = const []}) {
  return switch (raw) {
    'APPROVED' => Verdict.approved,
    'APPROVE_PENDING' => Verdict.approvePending,
    'REJECTED' => rejectionReasons.any(_closedSessionReasons.contains)
        ? Verdict.cancelled
        : Verdict.rejected,
    'REQUIRES_MANUAL_REVIEW' => Verdict.manualReview,
    'PENDING' ||
    'PROCESSING' ||
    'INITIATED' ||
    'DOCUMENT_SUBMITTED' ||
    'BIOMETRIC_SUBMITTED' =>
      Verdict.processing,
    'CANCELLED' => Verdict.cancelled,
    _ => Verdict.unknown,
  };
}
