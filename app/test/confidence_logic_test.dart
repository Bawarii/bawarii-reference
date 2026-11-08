import 'dart:io';

import 'package:bawarii_reference_app/models/confidence_tier.dart';
import 'package:bawarii_reference_app/models/extraction_quality_summary.dart';
import 'package:bawarii_reference_app/models/field_confidence_chip.dart';
import 'package:bawarii_reference_app/models/field_provenance.dart';
import 'package:bawarii_reference_app/models/identity_field_row.dart';
import 'package:bawarii_reference_app/models/issue_severity.dart';
import 'package:bawarii_reference_app/models/reference_result.dart';
import 'package:bawarii_reference_app/models/reference_workflow.dart';
import 'package:bawarii_reference_app/models/verdict.dart';
import 'package:bawarii_reference_app/theme/ref_colors.dart';
import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── tierOfConfidence ──────────────────────────

  group('tierOfConfidence', () {
    test('0.90 is high (boundary is inclusive)', () {
      expect(tierOfConfidence(0.90), ConfidenceTier.high);
    });

    test('0.95 is high', () {
      expect(tierOfConfidence(0.95), ConfidenceTier.high);
    });

    test('0.899 is check, just below the high boundary', () {
      expect(tierOfConfidence(0.899), ConfidenceTier.check);
    });

    test('0.70 is check (boundary is inclusive)', () {
      expect(tierOfConfidence(0.70), ConfidenceTier.check);
    });

    test('0.69 is review, just below the check boundary', () {
      expect(tierOfConfidence(0.69), ConfidenceTier.review);
    });

    test('0.50 is review', () {
      expect(tierOfConfidence(0.50), ConfidenceTier.review);
    });

    test('0.0 is review', () {
      expect(tierOfConfidence(0.0), ConfidenceTier.review);
    });
  });

  group('railColorForTier — client-tier rail never uses success green', () {
    test('high uses trustSoft, not success ("silence means confident")', () {
      expect(railColorForTier(ConfidenceTier.high), BawariiColors.trustSoft);
      expect(
        railColorForTier(ConfidenceTier.high),
        isNot(BawariiColors.success),
      );
    });

    test('check uses warningMid', () {
      expect(railColorForTier(ConfidenceTier.check), RefColors.warningMid);
    });

    test('review uses warning, never error/red', () {
      expect(railColorForTier(ConfidenceTier.review), BawariiColors.warning);
      expect(
        railColorForTier(ConfidenceTier.review),
        isNot(BawariiColors.error),
      );
    });
  });

  group('devConfidenceFillColorForTier — dev-tier bar allows success green',
      () {
    test('high uses success (technical audience, no verdict adjacency)', () {
      expect(
        devConfidenceFillColorForTier(ConfidenceTier.high),
        BawariiColors.success,
      );
    });
  });

  // ── chipsForField priority ordering ────────────────────

  group('chipsForField', () {
    test('high confidence, no issues → no chips', () {
      expect(chipsForField(confidence: 0.95, issues: const []), isEmpty);
    });

    test('review tier alone → Review chip', () {
      expect(
        chipsForField(confidence: 0.50, issues: const []),
        [FieldConfidenceChipKind.review],
      );
    });

    test('check tier alone → Check chip', () {
      expect(
        chipsForField(confidence: 0.85, issues: const []),
        [FieldConfidenceChipKind.check],
      );
    });

    test('priority: Review > Unmatched > Repaired > Check > One side only', () {
      // Review tier + every possible issue at once — only the two
      // highest-priority chips must survive the cap.
      final chips = chipsForField(
        confidence: 0.50,
        issues: const [
          'NIN_VIZ_MISMATCH',
          'NAME_TOKEN_REPAIRED',
          'NAME_UNCORROBORATED',
        ],
      );
      expect(chips, [
        FieldConfidenceChipKind.review,
        FieldConfidenceChipKind.unmatched,
      ]);
    });

    test('repaired name at check tier → Repaired + Check, max two', () {
      final chips = chipsForField(
        confidence: 0.75,
        issues: const ['NAME_TOKEN_REPAIRED', 'NAME_UNCORROBORATED'],
      );
      expect(chips.length, 2);
      expect(chips, [
        FieldConfidenceChipKind.repaired,
        FieldConfidenceChipKind.check,
      ]);
    });

    test('one side only only surfaces when there is room under the cap', () {
      final chips = chipsForField(
        confidence: 0.95,
        issues: const ['NAME_UNCORROBORATED'],
      );
      expect(chips, [FieldConfidenceChipKind.oneSide]);
    });

    // The merge
    // never emits MRZ_VIZ_MISMATCH as a field-level issue any more (it is
    // now a per-side, retake-class refusal), so the Unmatched chip's old
    // `i.contains('MISMATCH')` trigger for it is dead and must not fire.
    test(
        'MRZ_VIZ_MISMATCH alone no longer triggers the Unmatched chip '
        '(dead trigger dropped)', () {
      final chips = chipsForField(
        confidence: 0.95,
        issues: const ['MRZ_VIZ_MISMATCH'],
      );
      expect(chips, isEmpty);
    });

    // The new per-side SIDE_MISMATCH code also contains the substring
    // "MISMATCH" — confirms the fix is a real code match, not a narrower
    // substring that still happens to catch this one too.
    test('SIDE_MISMATCH alone does not trigger the Unmatched chip', () {
      final chips = chipsForField(
        confidence: 0.95,
        issues: const ['SIDE_MISMATCH'],
      );
      expect(chips, isEmpty);
    });

    test('NIN_VIZ_MISMATCH still triggers the Unmatched chip', () {
      final chips = chipsForField(
        confidence: 0.95,
        issues: const ['NIN_VIZ_MISMATCH'],
      );
      expect(chips, [FieldConfidenceChipKind.unmatched]);
    });
  });

  // ── issue severity classification ──────────────────────

  group('severityOfIssue', () {
    test('NAME_TOKEN_REPAIRED is advisory, not warning', () {
      expect(severityOfIssue('NAME_TOKEN_REPAIRED'), IssueSeverity.advisory);
    });

    test('NIN_VIZ_MISMATCH is warning', () {
      expect(severityOfIssue('NIN_VIZ_MISMATCH'), IssueSeverity.warning);
    });

    test('MRZ_NOT_FOUND is fatal', () {
      expect(severityOfIssue('MRZ_NOT_FOUND'), IssueSeverity.fatal);
    });

    test('unmapped code returns null rather than a guessed severity', () {
      expect(severityOfIssue('SOME_FUTURE_CODE'), isNull);
    });
  });

  // ── MRZ_VIZ_MISMATCH reclassified, SIDE_MISMATCH and
  // CROSS_CHECK_UNAVAILABLE added, with catalogue copy ──────────────────

  group('issue_severity.dart — complete vocabulary', () {
    // The service's published vocabulary is the source
    // of truth, split by which wire field actually carries each code:
    //
    //   extraction_meta.issues / extraction_meta.sides[side].issues — the
    //   eleven codes: NIN_NOT_FOUND, NAME_TOKEN_FILTERED,
    //   NAME_TOKEN_REPAIRED, NAME_SEPARATOR_REPAIRED, NAME_UNCORROBORATED,
    //   MRZ_CHECK_DIGIT_FAILED, NIN_VIZ_MISMATCH, DOB_DATE_INVALID,
    //   EXPIRY_DATE_INVALID, CROSS_CHECK_UNAVAILABLE, SIDE_DOB_MISMATCH.
    //   SIDE_DOB_MISMATCH is deliberately excluded below despite being on
    //   this list — dormant until front DOB extraction exists, no
    //   catalogue entry — leaving ten.
    //
    // document_sides.issues (a separate, per-side-only field) —
    //   the five capture codes (IMAGE_TOO_BLURRY, GLARE_DETECTED,
    //   DOCUMENT_NOT_FOUND, WRONG_SIDE, MRZ_UNREADABLE; resolved entirely
    //   within the SDK's own in-flow capture/retake screen and never
    //   reach this catalogue) plus SIDE_MISMATCH and MRZ_VIZ_MISMATCH
    // (these two DO reach extraction_meta.sides[side]
    //   .issues once the session is terminal, which is what this app's
    //   DocumentSidesCard reads, so they need an entry here).
    //
    // Defensive legacy rows: MRZ_NOT_FOUND,
    //   IMAGE_DECODE_ERROR, IMAGE_TOO_LARGE are kept even though they are
    //   not on the server's current "emits" list above — whether to drop
    //   them is decided later. None of the other internal
    //   pipeline-failure codes (OCR_ERROR, MRZ_PARSE_ERROR,
    //   VIZ_DARI_ERROR, LATIN_PASS_ERROR, DEPENDENCY_MISSING) are added.
    //
    // 10 + 2 + 3 = fifteen codes, every one with a severity and copy entry.
    const completeVocabulary = [
      'NAME_TOKEN_REPAIRED',
      'NAME_TOKEN_FILTERED',
      'NAME_SEPARATOR_REPAIRED',
      'NAME_UNCORROBORATED',
      'MRZ_CHECK_DIGIT_FAILED',
      'NIN_NOT_FOUND',
      'NIN_VIZ_MISMATCH',
      'MRZ_VIZ_MISMATCH',
      'DOB_DATE_INVALID',
      'EXPIRY_DATE_INVALID',
      'MRZ_NOT_FOUND',
      'IMAGE_DECODE_ERROR',
      'IMAGE_TOO_LARGE',
      'SIDE_MISMATCH',
      'CROSS_CHECK_UNAVAILABLE',
    ];

    for (final code in completeVocabulary) {
      test('$code has both a severity and a plain-language copy entry', () {
        expect(
          severityOfIssue(code),
          isNotNull,
          reason: '$code is missing from issueSeverities',
        );
        expect(
          plainLanguageForIssue(code),
          isNotNull,
          reason: '$code is missing from issuePlainLanguage',
        );
      });
    }

    test(
        'the vocabulary list itself is exactly what issueSeverities maps '
        '(nothing extra, nothing missing)', () {
      expect(issueSeverities.keys.toSet(), completeVocabulary.toSet());
    });

    test(
        'SIDE_DOB_MISMATCH is dormant — deliberately no catalogue entry', () {
      expect(severityOfIssue('SIDE_DOB_MISMATCH'), isNull);
      expect(plainLanguageForIssue('SIDE_DOB_MISMATCH'), isNull);
    });

    test(
        'MRZ_VIZ_MISMATCH is reclassified Fatal, retake-class — the stale '
        'merge-level Warning meaning is gone', () {
      expect(severityOfIssue('MRZ_VIZ_MISMATCH'), IssueSeverity.fatal);
      expect(retakeClassIssueCodes, contains('MRZ_VIZ_MISMATCH'));
      expect(
        plainLanguageForIssue('MRZ_VIZ_MISMATCH'),
        'This side was not used because it could not be checked from the '
        'photo. A new photo of the same card, flat and in good light, is '
        'needed.',
      );
      // The stale copy described a merge-level "field disagrees" meaning
      // that no longer exists.
      expect(
        plainLanguageForIssue('MRZ_VIZ_MISMATCH'),
        isNot(contains('disagrees with the printed')),
      );
    });

    test(
        'SIDE_MISMATCH is Fatal, retake-class, with its own distinct '
        'sentence', () {
      expect(severityOfIssue('SIDE_MISMATCH'), IssueSeverity.fatal);
      expect(retakeClassIssueCodes, contains('SIDE_MISMATCH'));
      expect(
        plainLanguageForIssue('SIDE_MISMATCH'),
        'This side was not used because it does not match the other side of '
        'the card. Both sides must come from the same card.',
      );
    });

    test(
        'CROSS_CHECK_UNAVAILABLE is Warning (merged result, not Fatal and '
        'not a retake-class code)', () {
      expect(severityOfIssue('CROSS_CHECK_UNAVAILABLE'), IssueSeverity.warning);
      expect(retakeClassIssueCodes, isNot(contains('CROSS_CHECK_UNAVAILABLE')));
      expect(
        plainLanguageForIssue('CROSS_CHECK_UNAVAILABLE'),
        'The front and back could not be matched to each other '
        'automatically, so this result could not be approved without a '
        'person checking it.',
      );
    });

    test(
        'neither retake-class sentence names the MRZ, the number, the '
        'printed text, or says fake/invalid/rejected', () {
      for (final code in retakeClassIssueCodes) {
        final copy = plainLanguageForIssue(code)!.toLowerCase();
        for (final forbidden in [
          'mrz',
          'machine-readable',
          'printed text',
          'fake',
          'invalid',
          'rejected',
        ]) {
          expect(
            copy,
            isNot(contains(forbidden)),
            reason: "$code's copy must not contain '$forbidden'",
          );
        }
      }
    });

    test(
        'retake-class codes are exactly MRZ_VIZ_MISMATCH and SIDE_MISMATCH '
        '— no fourth severity tier', () {
      expect(retakeClassIssueCodes, {'MRZ_VIZ_MISMATCH', 'SIDE_MISMATCH'});
      for (final code in retakeClassIssueCodes) {
        expect(severityOfIssue(code), IssueSeverity.fatal);
      }
    });

    // NAME_SEPARATOR_REPAIRED is
    // Advisory, with its own copy, and never adds a field chip (Repaired
    // stays tied to NAME_TOKEN_REPAIRED only — field_confidence_chip.dart).
    test(
        'NAME_SEPARATOR_REPAIRED is Advisory, with its own copy, and does '
        'not trigger the Repaired field chip', () {
      expect(
          severityOfIssue('NAME_SEPARATOR_REPAIRED'), IssueSeverity.advisory);
      expect(
        plainLanguageForIssue('NAME_SEPARATOR_REPAIRED'),
        'The surname and given names were separated automatically because '
        'the mark between them in the machine-readable zone could not be '
        'read cleanly.',
      );
      expect(retakeClassIssueCodes, isNot(contains('NAME_SEPARATOR_REPAIRED')));
      expect(
        chipsForField(
          confidence: 0.95,
          issues: const ['NAME_SEPARATOR_REPAIRED'],
        ),
        isEmpty,
      );
    });
  });

  group('field_provenance.dart — mismatch-code regression', () {
    test(
        'MRZ_VIZ_MISMATCH no longer produces the stale merge-level '
        '"disagrees with the printed text" copy via FieldProvenance', () {
      final p = FieldProvenance.derive(
        fieldKey: 'national_id',
        confidence: 0.50,
        issues: const ['MRZ_VIZ_MISMATCH'],
        fieldLabel: 'national id',
      );
      // _isMismatch now matches only NIN_VIZ_MISMATCH, so an
      // (unrealistic, defence-in-depth) MRZ_VIZ_MISMATCH field issue falls
      // through to the generic tier-based copy, never the mismatch branch.
      expect(p.whatWeDid, isNot(contains('disagrees with the printed')));
      expect(p.crossCheck, isNot('Disagrees with the printed text'));
    });

    test('SIDE_MISMATCH does not trigger the mismatch branch either', () {
      final p = FieldProvenance.derive(
        fieldKey: 'national_id',
        confidence: 0.50,
        issues: const ['SIDE_MISMATCH'],
        fieldLabel: 'national id',
      );
      expect(p.whatWeDid, isNot(contains('disagrees with the printed')));
    });

    test(
        'the stale "disagrees with the printed text" sentence does not '
        'survive anywhere under lib/', () {
      final hits = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.readAsStringSync().contains('disagrees with the printed')) {
          hits.add(entity.path);
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'stale MRZ_VIZ_MISMATCH merge-level copy found in: $hits',
      );
    });
  });

  group('issue_severity.dart — Dari/Pashto placeholders', () {
    // The reference app has no localisation plumbing yet — these placeholders fall back to English by construction
    // (every value is copied from issuePlainLanguage) until a native
    // speaker translates them.
    const newCodes = {
      'MRZ_VIZ_MISMATCH',
      'SIDE_MISMATCH',
      'CROSS_CHECK_UNAVAILABLE',
      'NAME_SEPARATOR_REPAIRED',
    };

    test('fa and ps each carry a placeholder for every new/recopied code', () {
      for (final code in newCodes) {
        expect(issuePlainLanguageFa[code], isNotNull, reason: code);
        expect(issuePlainLanguagePs[code], isNotNull, reason: code);
      }
    });

    test('fa and ps placeholders fall back to the English copy verbatim', () {
      for (final code in newCodes) {
        expect(issuePlainLanguageFa[code], plainLanguageForIssue(code));
        expect(issuePlainLanguagePs[code], plainLanguageForIssue(code));
      }
    });
  });

  group('uiCopy — result.sides.notUsed', () {
    test(
        'the key exists in English with fa/ps placeholders falling back '
        'to it verbatim', () {
      expect(uiCopy['result.sides.notUsed'], 'Not used');
      expect(uiCopyFa['result.sides.notUsed'], uiCopy['result.sides.notUsed']);
      expect(uiCopyPs['result.sides.notUsed'], uiCopy['result.sides.notUsed']);
    });
  });

  // ── FieldProvenance.derive ───────────

  group('FieldProvenance.derive', () {
    test('repaired name explains the reconstruction and flags for review', () {
      final p = FieldProvenance.derive(
        fieldKey: 'given_name_latin',
        confidence: 0.50,
        issues: const ['NAME_TOKEN_REPAIRED'],
        fieldLabel: 'given name',
      );
      expect(p.whatWeDid, contains('reconstructed from the machine-readable'));
      expect(p.whatWeDid, contains('flagged for review'));
    });

    test('high-confidence checksum field cites the checksum, not corroboration',
        () {
      final p = FieldProvenance.derive(
        fieldKey: 'national_id',
        confidence: 0.95,
        issues: const [],
        fieldLabel: 'national id',
      );
      expect(p.whatWeDid, contains('checksum'));
      expect(p.crossCheck, contains('checksum'));
    });

    test('sex field notes there is no checksum to confirm against', () {
      final p = FieldProvenance.derive(
        fieldKey: 'sex',
        confidence: 0.85,
        issues: const [],
        fieldLabel: 'sex',
      );
      expect(p.whatWeDid, contains('no checksum'));
    });

    test('NIN mismatch explains the disagreement, never blames the user', () {
      final p = FieldProvenance.derive(
        fieldKey: 'national_id',
        confidence: 0.50,
        issues: const ['NIN_VIZ_MISMATCH'],
        fieldLabel: 'national id',
      );
      expect(p.whatWeDid, contains('does not match'));
      expect(p.crossCheck, contains('Disagrees'));
    });

    // ── provenance mislabel ──────────────────────────────────
    // national_id, dob_gregorian, date_of_expiry_gregorian, sex,
    // surname_latin, and given_name_latin are ALL sourced from the back
    // side's machine-readable zone (the MRZ) — never from printed VIZ text,
    // which is only ever a corroboration source. "Read from" must always
    // say so; "printed text" belongs only in the cross-check narrative.

    test(
        'NIN mismatch reads from the machine-readable zone, cross-checks '
        'against the printed text', () {
      final p = FieldProvenance.derive(
        fieldKey: 'national_id',
        confidence: 0.50,
        issues: const ['NIN_VIZ_MISMATCH'],
        fieldLabel: 'national id',
      );
      expect(p.readFrom, contains('machine-readable zone'));
      expect(p.crossCheck, contains('printed text'));
    });

    test('sex field reads from the machine-readable zone', () {
      final p = FieldProvenance.derive(
        fieldKey: 'sex',
        confidence: 0.85,
        issues: const [],
        fieldLabel: 'sex',
      );
      expect(p.readFrom, contains('machine-readable zone'));
    });

    test(
        'high-confidence name field reads from the machine-readable zone '
        'and cross-checks against the printed text', () {
      final p = FieldProvenance.derive(
        fieldKey: 'surname_latin',
        confidence: 0.95,
        issues: const [],
        fieldLabel: 'surname',
      );
      expect(p.readFrom, contains('machine-readable zone'));
      expect(p.crossCheck, contains('printed text'));
    });

    test(
        'uncorroborated name field still reads from the machine-readable '
        'zone, not printed text', () {
      final p = FieldProvenance.derive(
        fieldKey: 'given_name_latin',
        confidence: 0.75,
        issues: const ['NAME_UNCORROBORATED'],
        fieldLabel: 'given name',
      );
      expect(p.readFrom, contains('machine-readable zone'));
    });

    test(
        'a checksum field at review-tier confidence (checksum failed, no '
        'mismatch) still reads from the machine-readable zone', () {
      // Regression for the pre-fix fallthrough into the generic switch,
      // which labelled this "printed text" even though national_id/dob/
      // expiry are always MRZ-sourced regardless of confidence tier.
      final p = FieldProvenance.derive(
        fieldKey: 'dob_gregorian',
        confidence: 0.50,
        issues: const [],
        fieldLabel: 'date of birth',
      );
      expect(p.readFrom, contains('machine-readable zone'));
    });

    test(
        'a checksum field at check-tier confidence still reads from the '
        'machine-readable zone', () {
      // Regression for the pre-fix fallthrough into the name-oriented
      // "tier == check" branch, which also labelled this "printed text".
      final p = FieldProvenance.derive(
        fieldKey: 'date_of_expiry_gregorian',
        confidence: 0.75,
        issues: const [],
        fieldLabel: 'date of expiry',
      );
      expect(p.readFrom, contains('machine-readable zone'));
    });

    test(
        'none of the six canonical fields are ever labelled as read from '
        'printed text — all six are MRZ-sourced', () {
      final scenarios = <FieldProvenance>[
        FieldProvenance.derive(
          fieldKey: 'national_id',
          confidence: 0.95,
          issues: const [],
          fieldLabel: 'national id',
        ),
        FieldProvenance.derive(
          fieldKey: 'dob_gregorian',
          confidence: 0.50,
          issues: const [],
          fieldLabel: 'date of birth',
        ),
        FieldProvenance.derive(
          fieldKey: 'date_of_expiry_gregorian',
          confidence: 0.75,
          issues: const [],
          fieldLabel: 'date of expiry',
        ),
        FieldProvenance.derive(
          fieldKey: 'sex',
          confidence: 0.85,
          issues: const [],
          fieldLabel: 'sex',
        ),
        FieldProvenance.derive(
          fieldKey: 'surname_latin',
          confidence: 0.95,
          issues: const [],
          fieldLabel: 'surname',
        ),
        FieldProvenance.derive(
          fieldKey: 'given_name_latin',
          confidence: 0.50,
          issues: const ['NAME_TOKEN_REPAIRED'],
          fieldLabel: 'given name',
        ),
      ];

      for (final p in scenarios) {
        expect(p.readFrom, isNot(contains('printed text')));
        expect(p.readFrom, contains('machine-readable zone'));
      }
    });
  });

  // ── buildIdentityFieldRows (real-data graceful degradation) ──────────────────

  group('buildIdentityFieldRows', () {
    ReferenceResult resultWith({
      String? surname,
      String? given,
      String? fullName,
      Map<String, double>? confidences,
      List<String> issues = const [],
    }) {
      return ReferenceResult(
        sessionId: 's',
        verdict: Verdict.approved,
        workflow: ReferenceWorkflow.documentAndLiveness,
        referenceId: 'r',
        checkedAt: null,
        surnameLatin: surname,
        givenNameLatin: given,
        fullName: fullName,
        nationalId: '0000-0000-00000',
        dateOfBirth: '1991-03-21',
        extractionMeta: confidences == null
            ? null
            : ExtractionMeta(fieldConfidences: confidences, issues: issues),
      );
    }

    test(
        'full contract: surname + given name render as separate rows, '
        'never a composite full-name row', () {
      final rows = buildIdentityFieldRows(
        resultWith(
          surname: 'PERSON',
          given: 'TEST PERSON',
          fullName: 'TEST PERSON',
          confidences: const {
            'surname_latin': 0.90,
            'given_name_latin': 0.50,
            'national_id': 0.95,
            'dob_gregorian': 0.95,
          },
        ),
      );

      expect(rows.map((r) => r.label), containsAll(['Surname', 'Given name']));
      expect(rows.map((r) => r.label), isNot(contains('Full name')));
    });

    test(
        'legacy shape (no constituents) falls back to a single plain '
        'Full name row with no confidence', () {
      final rows = buildIdentityFieldRows(
        resultWith(fullName: 'TEST PERSON', confidences: null),
      );

      final fullNameRow = rows.firstWhere((r) => r.label == 'Full name');
      expect(fullNameRow.confidence, isNull);
      expect(fullNameRow.key, isNull);
    });

    test(
        'a field with a value but no matching field_confidences entry '
        'renders plainly (old sessions)', () {
      final rows = buildIdentityFieldRows(
        resultWith(
          surname: 'PERSON',
          given: 'TEST PERSON',
          confidences: const {'surname_latin': 0.90},
        ),
      );

      final givenNameRow = rows.firstWhere((r) => r.label == 'Given name');
      expect(givenNameRow.confidence, isNull);
      expect(givenNameRow.provenance, isNull);
    });

    test(
        'name-related issues attach to the lower-confidence of the two '
        'name fields', () {
      final rows = buildIdentityFieldRows(
        resultWith(
          surname: 'PERSON',
          given: 'TEST PERSON',
          confidences: const {'surname_latin': 0.90, 'given_name_latin': 0.50},
          issues: const ['NAME_TOKEN_REPAIRED'],
        ),
      );

      final surnameRow = rows.firstWhere((r) => r.label == 'Surname');
      final givenRow = rows.firstWhere((r) => r.label == 'Given name');
      expect(givenRow.issues, contains('NAME_TOKEN_REPAIRED'));
      expect(surnameRow.issues, isEmpty);
    });
  });

  // ── ExtractionQualitySummary ────────────────────────────

  group('ExtractionQualitySummary.fromResult', () {
    test('reports the true fields-read count against field_confidences keys',
        () {
      final result = ReferenceResult(
        sessionId: 's',
        verdict: Verdict.approved,
        workflow: ReferenceWorkflow.documentAndLiveness,
        referenceId: 'r',
        checkedAt: null,
        surnameLatin: 'PERSON',
        // given_name_latin has a confidence entry but no value — unread.
        nationalId: '0000-0000-00000',
        extractionMeta: const ExtractionMeta(
          fieldConfidences: {
            'surname_latin': 0.90,
            'given_name_latin': 0.50,
            'national_id': 0.95,
          },
          sides: {
            'front': SideExtractionMeta(status: 'ACCEPTED', ocrConfidence: 0.8),
            'back': SideExtractionMeta(status: 'ACCEPTED', ocrConfidence: 0.9),
          },
          mrzValid: true,
        ),
      );

      final summary = ExtractionQualitySummary.fromResult(result);

      expect(summary.fieldsTotal, 3);
      expect(summary.fieldsRead, 2);
      expect(summary.mrzStatus, 'Valid');
      expect(summary.sidesStatus, 'Both');
    });
  });
}
