import 'dart:typed_data';

import 'package:bawarii_kyc/bawarii_kyc.dart';
import 'package:bawarii_reference_app/prefill_capturing_kyc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockKycRepository extends Mock implements IKycRepository {}

class _ProviderRepository extends Mock
    implements IKycRepository, BawariiLivenessModelSourceProvider {}

void main() {
  const sessionId = 'sess-test';
  final frontBytes = Uint8List.fromList([1, 2, 3]);
  final backBytes = Uint8List.fromList([4, 5, 6]);
  const prefill = BawariiPrefillData(
    sessionId: sessionId,
    nationalId: '123456789',
    dateOfBirth: '1988-03-22',
    fullName: 'Omar Barakzai',
  );

  late _MockKycRepository delegate;
  late PrefillCapturingKycRepository repo;

  setUp(() {
    delegate = _MockKycRepository();
    repo = PrefillCapturingKycRepository(delegate);
  });

  group('PrefillCapturingKycRepository', () {
    test('fetches prefill from the delegate as soon as both sides are ACCEPTED',
        () async {
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.front, frontBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.back, backBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      when(() => delegate.fetchPrefill(sessionId))
          .thenAnswer((_) async => prefill);

      await repo.uploadDocumentImage(sessionId, DocSide.front, frontBytes);
      verifyNever(() => delegate.fetchPrefill(sessionId));

      await repo.uploadDocumentImage(sessionId, DocSide.back, backBytes);
      verify(() => delegate.fetchPrefill(sessionId)).called(1);
    });

    test(
        'serves the captured prefill back through fetchPrefill without a '
        'second HTTP call', () async {
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.front, frontBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.back, backBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      when(() => delegate.fetchPrefill(sessionId))
          .thenAnswer((_) async => prefill);

      await repo.uploadDocumentImage(sessionId, DocSide.front, frontBytes);
      await repo.uploadDocumentImage(sessionId, DocSide.back, backBytes);

      final result = await repo.fetchPrefill(sessionId);

      expect(result, same(prefill));
      // Exactly the one call made during upload — fetchPrefill() itself
      // must not trigger another delegate call (the token may be burned by
      // the time a caller reaches for it here).
      verify(() => delegate.fetchPrefill(sessionId)).called(1);
    });

    test('does not fetch prefill until both sides are accepted', () async {
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.front, frontBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));

      await repo.uploadDocumentImage(sessionId, DocSide.front, frontBytes);

      verifyNever(() => delegate.fetchPrefill(sessionId));
      expect(await repo.fetchPrefill(sessionId), isNull);
    });

    test('a rejected side blocks the fetch even if the other side is accepted',
        () async {
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.front, frontBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      when(() =>
              delegate.uploadDocumentImage(sessionId, DocSide.back, backBytes))
          .thenAnswer((_) async => const DocumentUploadOutcome(
              status: DocumentUploadStatus.rejectedSide));

      await repo.uploadDocumentImage(sessionId, DocSide.front, frontBytes);
      await repo.uploadDocumentImage(sessionId, DocSide.back, backBytes);

      verifyNever(() => delegate.fetchPrefill(sessionId));
    });

    test('a retake that succeeds after an earlier rejection still fetches',
        () async {
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.front, frontBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      when(() =>
              delegate.uploadDocumentImage(sessionId, DocSide.back, backBytes))
          .thenAnswer((_) async => const DocumentUploadOutcome(
              status: DocumentUploadStatus.rejectedSide));
      when(() => delegate.fetchPrefill(sessionId))
          .thenAnswer((_) async => prefill);

      await repo.uploadDocumentImage(sessionId, DocSide.front, frontBytes);
      await repo.uploadDocumentImage(sessionId, DocSide.back, backBytes);
      verifyNever(() => delegate.fetchPrefill(sessionId));

      // Retake succeeds.
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.back, backBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      await repo.uploadDocumentImage(sessionId, DocSide.back, backBytes);

      verify(() => delegate.fetchPrefill(sessionId)).called(1);
    });

    test('only fetches once even if both-accepted is observed again', () async {
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.front, frontBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.back, backBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      when(() => delegate.fetchPrefill(sessionId))
          .thenAnswer((_) async => prefill);

      await repo.uploadDocumentImage(sessionId, DocSide.front, frontBytes);
      await repo.uploadDocumentImage(sessionId, DocSide.back, backBytes);
      // Idempotent re-upload of an already-accepted side (e.g. retry).
      await repo.uploadDocumentImage(sessionId, DocSide.back, backBytes);

      verify(() => delegate.fetchPrefill(sessionId)).called(1);
    });

    test(
        'document_only-shaped flow: prefill fetch failing (token already '
        'burned) resolves to null rather than throwing', () async {
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.front, frontBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      when(() =>
          delegate.uploadDocumentImage(
              sessionId, DocSide.back, backBytes)).thenAnswer((_) async =>
          const DocumentUploadOutcome(status: DocumentUploadStatus.accepted));
      when(() => delegate.fetchPrefill(sessionId)).thenThrow(
        Exception('401 Upload token has already been used'),
      );

      await repo.uploadDocumentImage(sessionId, DocSide.front, frontBytes);
      await repo.uploadDocumentImage(sessionId, DocSide.back, backBytes);

      expect(await repo.fetchPrefill(sessionId), isNull);
    });

    test('delegates uploadSelfieResult, pollVerdict, and dispose unchanged',
        () async {
      const liveness = LivenessResult(
        isLive: true,
        livenessScore: 0.95,
        blinkDetected: true,
        headMovementDetected: true,
        processingTimeMs: 1200,
        sdkVersion: 'mlkit_minifasnet_v1',
      );
      when(() => delegate.uploadSelfieResult(sessionId, liveness))
          .thenAnswer((_) async {});
      when(() => delegate.pollVerdict(sessionId)).thenAnswer(
        (_) async => const KycPollVerdict(
          verdict: KycVerdict.verified,
          faceMatch: BawariiFaceMatch.unreported,
        ),
      );
      when(() => delegate.dispose()).thenAnswer((_) async {});

      await repo.uploadSelfieResult(sessionId, liveness);
      final verdict = await repo.pollVerdict(sessionId);
      await repo.dispose();

      expect(verdict.verdict, KycVerdict.verified);
      verify(() => delegate.uploadSelfieResult(sessionId, liveness)).called(1);
      verify(() => delegate.pollVerdict(sessionId)).called(1);
      verify(() => delegate.dispose()).called(1);
    });

    test('forwards the delegate\'s default liveness model source', () {
      final source = BytesLivenessModelSource(Uint8List(1));
      final provider = _ProviderRepository();
      when(() => provider.createDefaultLivenessModelSource())
          .thenReturn(source);

      final wrapped = PrefillCapturingKycRepository(provider);

      expect(wrapped.createDefaultLivenessModelSource(), same(source));
    });

    test('throws when the delegate provides no model source', () {
      expect(
        () => repo.createDefaultLivenessModelSource(),
        throwsStateError,
      );
    });
  });
}
