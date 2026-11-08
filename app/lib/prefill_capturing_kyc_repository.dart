import 'dart:typed_data';

import 'package:bawarii_kyc/bawarii_kyc.dart';

/// Wraps an [IKycRepository] so prefill is fetched while the upload token is
/// still live, instead of after the SDK flow completes.
///
/// `/prefill` is strictly single-use (`require_upload_token`); once the
/// terminal step burns the token's JTI, every subsequent read 401s. For
/// `document_and_liveness` that terminal step is `POST /biometric`
/// (`HttpKycRepository.uploadSelfieResult`), which the SDK calls only after
/// both document sides are ACCEPTED. This decorator observes
/// [uploadDocumentImage] responses and fires the real prefill fetch the
/// moment both sides are known ACCEPTED — i.e. before the SDK has any chance
/// to call `uploadSelfieResult` — then serves that captured value back
/// through [fetchPrefill] instead of making a second, post-burn request.
///
/// For `document_only` there is no biometric step: the session's own
/// terminal decision (and JTI burn on the platform) is reached synchronously inside the same HTTP response
/// that accepts the second document side, before this decorator's
/// [uploadDocumentImage] override even returns. Prefill has no live window
/// left to fetch into by that point, so [fetchPrefill] legitimately resolves
/// to null for that workflow — [PreCaptureScreen] already treats a null/empty
/// prefill as "go straight to ResultScreen", which is the correct UX for a
/// workflow whose decision is already final by the time capture finishes.
class PrefillCapturingKycRepository
    implements IKycRepository, BawariiLivenessModelSourceProvider {
  PrefillCapturingKycRepository(this._delegate);

  final IKycRepository _delegate;
  final Set<DocSide> _acceptedSides = {};
  bool _fetchAttempted = false;
  BawariiPrefillData? _capturedPrefill;

  @override
  BawariiKycEnvironment get environment => _delegate.environment;

  @override
  Future<DocumentUploadOutcome> uploadDocumentImage(
    String sessionId,
    DocSide side,
    Uint8List bytes,
  ) async {
    final outcome = await _delegate.uploadDocumentImage(
      sessionId,
      side,
      bytes,
    );

    if (outcome.status == DocumentUploadStatus.accepted) {
      _acceptedSides.add(side);
    } else {
      // A rejected retake invalidates a previously-accepted read of this
      // side; wait for the next ACCEPTED before considering both sides done.
      _acceptedSides.remove(side);
    }

    final bothSidesAccepted = _acceptedSides.contains(DocSide.front) &&
        _acceptedSides.contains(DocSide.back);

    if (bothSidesAccepted && !_fetchAttempted) {
      _fetchAttempted = true;
      try {
        _capturedPrefill = await _delegate.fetchPrefill(sessionId);
      } catch (_) {
        _capturedPrefill = null;
      }
    }

    return outcome;
  }

  @override
  Future<void> uploadSelfieResult(String sessionId, LivenessResult result) =>
      _delegate.uploadSelfieResult(sessionId, result);

  @override
  Future<KycPollVerdict> pollVerdict(String sessionId) =>
      _delegate.pollVerdict(sessionId);

  // Return type inferred from IKycRepository.fetchResultSnapshot
  // (KycResultSnapshot is not part of this package's exported surface).
  @override
  fetchResultSnapshot(String sessionId) =>
      _delegate.fetchResultSnapshot(sessionId);

  /// Returns the prefill captured before the upload token was burned.
  ///
  /// Never issues a new HTTP request — by the time the SDK flow completes
  /// and callers reach for prefill, the token may already be single-use
  /// consumed. [sessionId] is accepted to satisfy [IKycRepository] but is
  /// not used; the captured value is already scoped to this repository's
  /// session.
  @override
  Future<BawariiPrefillData?> fetchPrefill(String sessionId) async =>
      _capturedPrefill;

  /// Forwards the SDK's default liveness-model source (runtime fetch with the
  /// session's upload token). A decorator must forward this: without it the
  /// SDK cannot see the delegate's token. The model ships only through that
  /// runtime source, so a delegate that provides none is a programming error.
  @override
  BawariiLivenessModelSource createDefaultLivenessModelSource() {
    final delegate = _delegate;
    if (delegate is BawariiLivenessModelSourceProvider) {
      return (delegate as BawariiLivenessModelSourceProvider)
          .createDefaultLivenessModelSource();
    }
    throw StateError(
      'The wrapped repository does not provide a liveness model source.',
    );
  }

  @override
  Future<void> dispose() => _delegate.dispose();
}
