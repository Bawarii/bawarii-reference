import 'package:bawarii_reference_app/models/reference_result.dart';
import 'package:bawarii_reference_app/models/reference_workflow.dart';
import 'package:bawarii_reference_app/models/rejection_copy.dart';
import 'package:bawarii_reference_app/models/verdict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Verdict mapping ─────────────────────────────────────────────────────────

  group('verdictFromApi', () {
    test('APPROVED → approved', () {
      expect(verdictFromApi('APPROVED'), Verdict.approved);
    });

    test('REJECTED → rejected', () {
      expect(verdictFromApi('REJECTED'), Verdict.rejected);
    });

    test('REQUIRES_MANUAL_REVIEW → manualReview', () {
      expect(verdictFromApi('REQUIRES_MANUAL_REVIEW'), Verdict.manualReview);
    });

    test('PROCESSING → processing', () {
      expect(verdictFromApi('PROCESSING'), Verdict.processing);
    });

    test('INITIATED → processing', () {
      expect(verdictFromApi('INITIATED'), Verdict.processing);
    });

    test('DOCUMENT_SUBMITTED → processing', () {
      expect(verdictFromApi('DOCUMENT_SUBMITTED'), Verdict.processing);
    });

    test('BIOMETRIC_SUBMITTED → processing', () {
      expect(verdictFromApi('BIOMETRIC_SUBMITTED'), Verdict.processing);
    });

    // Legacy tolerance only; APPROVE_PENDING no longer appears on
    // the wire (the server now emits REQUIRES_MANUAL_REVIEW instead).
    test('APPROVE_PENDING → approvePending (legacy tolerance)', () {
      expect(verdictFromApi('APPROVE_PENDING'), Verdict.approvePending);
    });

    test('APPROVE_PENDING is distinct from unknown', () {
      expect(verdictFromApi('APPROVE_PENDING'), isNot(Verdict.unknown));
    });

    // CANCELLED is distinguishable from UNKNOWN. Legacy tolerance
    // only — the live wire value is now REJECTED + rejection_reasons (see
    // the 'REJECTED + rejection_reasons' group below).
    test('CANCELLED → cancelled (legacy tolerance)', () {
      expect(verdictFromApi('CANCELLED'), Verdict.cancelled);
    });

    test('CANCELLED is distinct from unknown', () {
      expect(verdictFromApi('CANCELLED'), isNot(Verdict.unknown));
    });

    test('null → unknown', () {
      expect(verdictFromApi(null), Verdict.unknown);
    });

    test('arbitrary string → unknown', () {
      expect(verdictFromApi('SOME_NEW_STATUS'), Verdict.unknown);
    });

    // PENDING is
    // the single literal the server emits for every non-terminal state.
    test('PENDING → processing', () {
      expect(verdictFromApi('PENDING'), Verdict.processing);
    });
  });

  group('verdictFromApi — REJECTED + rejection_reasons', () {
    test('REJECTED with no rejection_reasons → rejected', () {
      expect(verdictFromApi('REJECTED'), Verdict.rejected);
    });

    test(
      'REJECTED with an ordinary rejection reason stays rejected',
      () {
        expect(
          verdictFromApi('REJECTED', rejectionReasons: ['LIVENESS_FAILED']),
          Verdict.rejected,
        );
      },
    );

    test(
      'REJECTED with rejection_reasons: [SESSION_CANCELLED] → cancelled',
      () {
        expect(
          verdictFromApi(
            'REJECTED',
            rejectionReasons: ['SESSION_CANCELLED'],
          ),
          Verdict.cancelled,
        );
      },
    );

    // No dedicated "expired" presentation exists yet, so this
    // reuses the cancelled/closed-session presentation.
    test(
      'REJECTED with rejection_reasons: [SESSION_EXPIRED] → cancelled',
      () {
        expect(
          verdictFromApi('REJECTED', rejectionReasons: ['SESSION_EXPIRED']),
          Verdict.cancelled,
        );
      },
    );
  });

  // ── ReferenceResult.fromJson ────────────────────────────────────────────────

  group('ReferenceResult.fromJson', () {
    test('parses nested fields from approved response', () {
      final json = {
        'session_id': 'sess-001',
        'verdict': 'APPROVED',
        'workflow': 'document_and_liveness',
        'reference_id': 'ref-abc',
        'checked_at': '2026-07-05T10:00:00Z',
        'pending_steps': <dynamic>[],
        'rejection_reasons': null,
        'fields': {
          'document_type': 'E_TAZKIRA',
          'extracted_fields_hash': 'abc123',
          'national_id': '00-0000-001',
          'dob_gregorian': '1980-01-01',
          'given_name_latin': 'TEST',
          'surname_latin': 'PERSON',
          'full_name': 'TEST PERSON',
        },
      };

      final result = ReferenceResult.fromJson(json);

      expect(result.sessionId, 'sess-001');
      expect(result.verdict, Verdict.approved);
      expect(result.workflow, ReferenceWorkflow.documentAndLiveness);
      expect(result.referenceId, 'ref-abc');
      expect(result.fullName, 'TEST PERSON');
      expect(result.dateOfBirth, '1980-01-01');
      expect(result.nationalId, '00-0000-001');
      expect(result.documentType, 'E_TAZKIRA');
      expect(result.rejectionReasons, isEmpty);
    });

    test('fields null → all identity fields null', () {
      final json = {
        'session_id': 'sess-002',
        'verdict': 'INITIATED',
        'workflow': 'document_only',
        'reference_id': null,
        'checked_at': null,
        'pending_steps': <dynamic>[],
        'rejection_reasons': null,
        'fields': null,
      };

      final result = ReferenceResult.fromJson(json);

      expect(result.fullName, isNull);
      expect(result.dateOfBirth, isNull);
      expect(result.nationalId, isNull);
      expect(result.documentType, isNull);
      expect(result.verdict, Verdict.processing);
    });

    test('parses rejection_reasons list', () {
      final json = {
        'session_id': 'sess-003',
        'verdict': 'REJECTED',
        'workflow': 'document_and_liveness',
        'reference_id': 'ref-rej',
        'checked_at': '2026-07-05T11:00:00Z',
        'pending_steps': <dynamic>[],
        'rejection_reasons': ['LIVENESS_FAILED', 'FACIAL_MATCH_INSUFFICIENT'],
        'fields': null,
      };

      final result = ReferenceResult.fromJson(json);

      expect(result.verdict, Verdict.rejected);
      expect(result.rejectionReasons, [
        'LIVENESS_FAILED',
        'FACIAL_MATCH_INSUFFICIENT',
      ]);
    });

    // A cancelled session now arrives as REJECTED with
    // rejection_reasons: ["SESSION_CANCELLED"], not a CANCELLED verdict.
    test(
      'REJECTED + rejection_reasons: [SESSION_CANCELLED] → Verdict.cancelled',
      () {
        final json = {
          'session_id': 'sess-009',
          'verdict': 'REJECTED',
          'workflow': 'document_and_liveness',
          'reference_id': 'ref-cancelled',
          'checked_at': '2026-10-07T11:00:00Z',
          'pending_steps': <dynamic>[],
          'rejection_reasons': ['SESSION_CANCELLED'],
          'fields': null,
        };

        final result = ReferenceResult.fromJson(json);

        expect(result.verdict, Verdict.cancelled);
        expect(result.rejectionReasons, ['SESSION_CANCELLED']);
      },
    );

    // An expired session, likewise REJECTED + rejection_reasons.
    test(
      'REJECTED + rejection_reasons: [SESSION_EXPIRED] → Verdict.cancelled',
      () {
        final json = {
          'session_id': 'sess-010',
          'verdict': 'REJECTED',
          'workflow': 'document_and_liveness',
          'reference_id': 'ref-expired',
          'checked_at': '2026-10-07T11:00:00Z',
          'pending_steps': <dynamic>[],
          'rejection_reasons': ['SESSION_EXPIRED'],
          'fields': null,
        };

        final result = ReferenceResult.fromJson(json);

        expect(result.verdict, Verdict.cancelled);
        expect(result.rejectionReasons, ['SESSION_EXPIRED']);
      },
    );

    // PENDING is the live non-terminal literal.
    test('verdict: PENDING → Verdict.processing', () {
      final json = {
        'session_id': 'sess-011',
        'verdict': 'PENDING',
        'workflow': 'document_and_liveness',
        'reference_id': null,
        'checked_at': null,
        'pending_steps': ['BIOMETRIC_SUBMITTED'],
        'rejection_reasons': null,
        'fields': null,
      };

      final result = ReferenceResult.fromJson(json);

      expect(result.verdict, Verdict.processing);
      expect(result.pendingSteps, ['BIOMETRIC_SUBMITTED']);
    });

    test('missing pending_steps key defaults to empty list', () {
      final json = {
        'session_id': 'sess-004',
        'verdict': 'APPROVED',
        'workflow': 'document_only',
        'reference_id': 'ref-x',
        'checked_at': null,
        'fields': null,
      };

      final result = ReferenceResult.fromJson(json);

      expect(result.pendingSteps, isEmpty);
      expect(result.rejectionReasons, isEmpty);
    });

    test('fields with partial keys — missing keys yield null', () {
      final json = {
        'session_id': 'sess-005',
        'verdict': 'APPROVED',
        'workflow': 'document_only',
        'reference_id': null,
        'checked_at': null,
        'fields': {
          'national_id': '99-1234-567',
          // full_name, dob_gregorian, document_type absent
        },
      };

      final result = ReferenceResult.fromJson(json);

      expect(result.nationalId, '99-1234-567');
      expect(result.fullName, isNull);
      expect(result.dateOfBirth, isNull);
      expect(result.documentType, isNull);
    });

    // ── extraction_meta ──────────────────────────────────────────

    test('extraction_meta absent → extractionMeta is null', () {
      final json = {
        'session_id': 'sess-006',
        'verdict': 'APPROVED',
        'workflow': 'document_and_liveness',
        'reference_id': 'ref-no-meta',
        'checked_at': null,
        'fields': null,
        // no "extraction_meta" key at all — old session / Bearer channel.
      };

      final result = ReferenceResult.fromJson(json);

      expect(result.extractionMeta, isNull);
    });

    test('parses full extraction_meta shape', () {
      final json = {
        'session_id': 'sess-007',
        'verdict': 'APPROVED',
        'workflow': 'document_and_liveness',
        'reference_id': 'ref-meta',
        'checked_at': '2026-09-12T10:00:00Z',
        'fields': null,
        'extraction_meta': {
          'field_confidences': {
            'national_id': 0.95,
            'surname_latin': 0.90,
            'given_name_latin': 0.50,
          },
          'sides': {
            'front': {
              'status': 'ACCEPTED',
              'issues': <dynamic>[],
              'ocr_confidence': 0.93,
              'mrz_valid': null,
            },
            'back': {
              'status': 'ACCEPTED',
              'issues': ['NAME_TOKEN_REPAIRED'],
              'ocr_confidence': 0.95,
              'mrz_valid': true,
            },
          },
          'mrz_valid': true,
          'ocr_confidence': 0.95,
          'issues': ['NAME_TOKEN_REPAIRED'],
          'schema_version': '1.0',
        },
      };

      final result = ReferenceResult.fromJson(json);
      final meta = result.extractionMeta;

      expect(meta, isNotNull);
      expect(meta!.fieldConfidences, {
        'national_id': 0.95,
        'surname_latin': 0.90,
        'given_name_latin': 0.50,
      });
      expect(meta.mrzValid, isTrue);
      expect(meta.ocrConfidence, 0.95);
      expect(meta.issues, ['NAME_TOKEN_REPAIRED']);
      expect(meta.schemaVersion, '1.0');

      expect(meta.sides['front']!.status, 'ACCEPTED');
      expect(meta.sides['front']!.issues, isEmpty);
      expect(meta.sides['front']!.ocrConfidence, 0.93);
      expect(meta.sides['front']!.mrzValid, isNull);

      expect(meta.sides['back']!.status, 'ACCEPTED');
      expect(meta.sides['back']!.issues, ['NAME_TOKEN_REPAIRED']);
      expect(meta.sides['back']!.ocrConfidence, 0.95);
      expect(meta.sides['back']!.mrzValid, isTrue);
    });

    test('extraction_meta with missing optional keys defaults gracefully', () {
      final json = {
        'session_id': 'sess-008',
        'verdict': 'APPROVED',
        'workflow': 'document_only',
        'reference_id': 'ref-meta-partial',
        'checked_at': null,
        'fields': null,
        'extraction_meta': <String, dynamic>{},
      };

      final result = ReferenceResult.fromJson(json);
      final meta = result.extractionMeta;

      expect(meta, isNotNull);
      expect(meta!.fieldConfidences, isEmpty);
      expect(meta.sides, isEmpty);
      expect(meta.mrzValid, isNull);
      expect(meta.ocrConfidence, isNull);
      expect(meta.issues, isEmpty);
      expect(meta.schemaVersion, isNull);
    });
  });

  // ── rejectionMessage ────────────────────────────────────────────────────────

  group('rejectionMessage', () {
    test('known codes return human-readable copy', () {
      expect(
        rejectionMessage('LIVENESS_FAILED'),
        contains('did not confirm a live person'),
      );
      expect(
        rejectionMessage('FACIAL_MATCH_INSUFFICIENT'),
        contains('selfie'),
      );
      expect(
        rejectionMessage('DOCUMENT_EXTRACTION_FAILED'),
        contains('read the required fields'),
      );
      expect(
        rejectionMessage('VERIFICATION_INCONCLUSIVE'),
        contains('confidence'),
      );
    });

    test('unknown code returns the raw code', () {
      expect(rejectionMessage('UNKNOWN_CODE_XYZ'), 'UNKNOWN_CODE_XYZ');
    });
  });

  // ── rejectionMessage ────────────────────────────────────

  group('rejectionMessage — complete rejection_reasons coverage', () {
    // The fifteen codes the table maps. Most are emitted by the platform's
    // decision engine and manual-review flow; the rest (SIDE_MISMATCH,
    // MRZ_VIZ_MISMATCH, LIVENESS_FAILED, FACIAL_MATCH_FAILED,
    // DOCUMENT_TAMPERED, SIDE_DOB_MISMATCH, SESSION_EXPIRED,
    // SESSION_CANCELLED) are documented, some not yet emitted (SIDE_DOB_MISMATCH is dormant,
    // DOCUMENT_TAMPERED has no emitting code path today).
    const allRejectionCodes = [
      'SIDE_MISMATCH',
      'MRZ_VIZ_MISMATCH',
      'LIVENESS_FAILED',
      'FACIAL_MATCH_FAILED',
      'FACIAL_MATCH_INSUFFICIENT',
      'DOCUMENT_TAMPERED',
      'DOCUMENT_FLAGGED',
      'MANUAL_REVIEW_REJECTED',
      'SIDE_DOB_MISMATCH',
      'CROSS_CHECK_UNAVAILABLE',
      'SESSION_EXPIRED',
      'SESSION_CANCELLED',
      'DOCUMENT_EXTRACTION_FAILED',
      'VERIFICATION_INCONCLUSIVE',
      'SANDBOX_REAL_DOCUMENT_REJECTED',
    ];

    test('all fifteen codes are known — none fall back to the raw code', () {
      for (final code in allRejectionCodes) {
        expect(
          knownRejectionCodes.contains(code),
          isTrue,
          reason: '$code is missing from knownRejectionCodes',
        );
        expect(
          rejectionMessage(code),
          isNot(code),
          reason: '$code fell back to its own raw value',
        );
      }
    });

    test(
        'the terminal retake-class sentences name the last attempt only, '
        'after three attempts, and never say fake/invalid/rejected', () {
      for (final code in ['SIDE_MISMATCH', 'MRZ_VIZ_MISMATCH']) {
        final copy = rejectionMessage(code);
        expect(copy, contains('three photo attempts'));
        for (final forbidden in ['fake', 'invalid', 'rejected', 'mrz']) {
          expect(
            copy.toLowerCase(),
            isNot(contains(forbidden)),
            reason: "$code's terminal copy must not contain '$forbidden'",
          );
        }
      }
    });

    test(
        'FACIAL_MATCH_FAILED and FACIAL_MATCH_INSUFFICIENT share the same '
        'sentence (one name pending service agreement)', () {
      expect(
        rejectionMessage('FACIAL_MATCH_FAILED'),
        rejectionMessage('FACIAL_MATCH_INSUFFICIENT'),
      );
    });

    test(
        'DOCUMENT_FLAGGED is generic — names no list and no check '
        '(never shown to the applicant verbatim)', () {
      final copy = rejectionMessage('DOCUMENT_FLAGGED').toLowerCase();
      for (final forbidden in ['list', 'blacklist', 'flagged', 'watchlist']) {
        expect(copy, isNot(contains(forbidden)));
      }
    });

    test(
        'a code outside the fifteen still falls back to the raw chip '
        'value (open list, not a closed vocabulary)', () {
      expect(rejectionMessage('SOME_FUTURE_REASON'), 'SOME_FUTURE_REASON');
      expect(knownRejectionCodes.contains('SOME_FUTURE_REASON'), isFalse);
    });
  });
}
