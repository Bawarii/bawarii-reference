import 'package:bawarii_reference_app/models/reference_result.dart';
import 'package:bawarii_reference_app/models/reference_workflow.dart';
import 'package:bawarii_reference_app/models/verdict.dart';
import 'package:bawarii_reference_app/models/rejection_copy.dart';
import 'package:bawarii_reference_app/theme/ref_colors.dart';
import 'package:bawarii_reference_app/widgets/primitives/rb_chip.dart';
import 'package:bawarii_reference_app/widgets/result/document_sides_card.dart';
import 'package:bawarii_reference_app/widgets/result/rejection_details.dart';
import 'package:bawarii_reference_app/widgets/result/identity_field_row_tile.dart';
import 'package:bawarii_reference_app/models/confidence_tier.dart';
import 'package:bawarii_reference_app/models/identity_field_row.dart';
import 'package:bawarii_reference_app/widgets/verdict_hero_card.dart';
import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(theme: BawariiTheme.light(), home: Scaffold(body: child));
}

ReferenceResult _resultWith(Verdict verdict) {
  return ReferenceResult(
    sessionId: 'sess-1',
    verdict: verdict,
    workflow: ReferenceWorkflow.documentAndLiveness,
    referenceId: 'ref-1',
    checkedAt: '2026-09-17T09:14:35Z',
  );
}

Color _fillOf(WidgetTester tester) {
  final container = tester.widget<Container>(find.byType(Container).first);
  final decoration = container.decoration as BoxDecoration;
  return decoration.color!;
}

void main() {
  group('VerdictHeroCard', () {
    testWidgets(
        'APPROVE_PENDING renders as a positive success state, '
        'never the grey "could not be determined" UNKNOWN treatment',
        (tester) async {
      await tester.pumpWidget(
        _wrap(VerdictHeroCard(result: _resultWith(Verdict.approvePending))),
      );

      expect(find.text('APPROVED — PENDING CHECKS'), findsOneWidget);
      expect(
        find.textContaining('could not be determined'),
        findsNothing,
      );
      expect(_fillOf(tester), BawariiColors.successSoft);
      expect(_fillOf(tester), isNot(BawariiColors.ink10));
    });

    testWidgets('CANCELLED is visually distinct from UNKNOWN', (tester) async {
      await tester.pumpWidget(
        _wrap(VerdictHeroCard(result: _resultWith(Verdict.cancelled))),
      );

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('UNKNOWN'), findsNothing);
    });

    testWidgets('UNKNOWN still renders its own "could not be determined" copy',
        (tester) async {
      await tester.pumpWidget(
        _wrap(VerdictHeroCard(result: _resultWith(Verdict.unknown))),
      );

      expect(find.text('UNKNOWN'), findsOneWidget);
      expect(
        find.textContaining('could not be determined'),
        findsOneWidget,
      );
    });

    testWidgets('APPROVED shows the success hero, not pending-checks copy',
        (tester) async {
      await tester.pumpWidget(
        _wrap(VerdictHeroCard(result: _resultWith(Verdict.approved))),
      );

      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.textContaining('PENDING'), findsNothing);
    });
  });

  group('IdentityFieldRowTile — confidence tier rendering', () {
    testWidgets(
        'high-confidence field shows no confidence chip (silence '
        'means confident)', (tester) async {
      const row = IdentityFieldRow(
        key: 'national_id',
        label: 'National ID',
        value: '0000-0000-00000',
        mono: true,
        confidence: 0.95,
      );

      await tester.pumpWidget(
        _wrap(
          IdentityFieldRowTile(
            row: row,
            revealed: true,
            onToggleReveal: () {},
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Check'), findsNothing);
      expect(find.text('Review'), findsNothing);
    });

    testWidgets('review-tier field shows the Review chip', (tester) async {
      const row = IdentityFieldRow(
        key: 'given_name_latin',
        label: 'Given name',
        value: 'TEST PERSON',
        mono: false,
        confidence: 0.50,
      );

      await tester.pumpWidget(
        _wrap(
          IdentityFieldRowTile(
            row: row,
            revealed: false,
            onToggleReveal: () {},
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('masked national_id shows bullets until revealed',
        (tester) async {
      const row = IdentityFieldRow(
        key: 'national_id',
        label: 'National ID',
        value: '0000-0000-00000',
        mono: true,
        mask: true,
        confidence: 0.95,
      );

      await tester.pumpWidget(
        _wrap(
          IdentityFieldRowTile(
            row: row,
            revealed: false,
            onToggleReveal: () {},
            onTap: () {},
          ),
        ),
      );

      expect(find.textContaining('••••••••••'), findsOneWidget);
      expect(find.text('0000-0000-00000'), findsNothing);
    });

    testWidgets('field with no confidence data renders plainly, no rail chip',
        (tester) async {
      const row = IdentityFieldRow(
        key: null,
        label: 'Full name',
        value: 'TEST PERSON',
        mono: false,
      );

      await tester.pumpWidget(
        _wrap(
          IdentityFieldRowTile(
            row: row,
            revealed: false,
            onToggleReveal: () {},
            onTap: () {},
          ),
        ),
      );

      expect(find.text('TEST PERSON'), findsOneWidget);
      expect(find.text('Check'), findsNothing);
      expect(find.text('Review'), findsNothing);
    });
  });

  group('ConfidenceTier boundary sanity used by the tile', () {
    test('0.899 and 0.90 land on opposite sides of the High boundary', () {
      expect(tierOfConfidence(0.899), isNot(tierOfConfidence(0.90)));
    });
  });

  // ── DocumentSidesCard / side status pill ──────

  group('DocumentSidesCard — retake-class side status pill', () {
    ExtractionMeta metaWithBack({
      required String status,
      List<String> issues = const [],
    }) {
      return ExtractionMeta(
        sides: {
          'back': SideExtractionMeta(
            status: status,
            ocrConfidence: 0.9,
            issues: issues,
          ),
        },
      );
    }

    testWidgets(
        'MRZ_VIZ_MISMATCH shows "Not used", never "Rejected", with '
        'its retake copy', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSidesCard(
            extractionMeta: metaWithBack(
              status: 'SIDE_FAILED',
              issues: const ['MRZ_VIZ_MISMATCH'],
            ),
          ),
        ),
      );

      expect(find.text('Not used'), findsOneWidget);
      expect(find.text('Rejected'), findsNothing);
      expect(
        find.textContaining('A new photo of the same card, flat and in '
            'good light, is needed.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'SIDE_MISMATCH shows "Not used", never "Rejected", with its '
        'own retake copy', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSidesCard(
            extractionMeta: metaWithBack(
              status: 'SIDE_FAILED',
              issues: const ['SIDE_MISMATCH'],
            ),
          ),
        ),
      );

      expect(find.text('Not used'), findsOneWidget);
      expect(find.text('Rejected'), findsNothing);
      expect(
        find.textContaining('Both sides must come from the same card.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'a genuine content-level fatal code (MRZ_NOT_FOUND) still '
        'shows "Rejected", not "Not used"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSidesCard(
            extractionMeta: metaWithBack(
              status: 'SIDE_FAILED',
              issues: const ['MRZ_NOT_FOUND'],
            ),
          ),
        ),
      );

      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Not used'), findsNothing);
    });

    testWidgets(
        'a side whose own reported status is REJECTED (no '
        'retake-class issue) still shows "Rejected" (AC7: Rejected stays '
        'where the status really is REJECTED)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSidesCard(
            extractionMeta: metaWithBack(status: 'REJECTED'),
          ),
        ),
      );

      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Not used'), findsNothing);
    });

    // ── warning tier + side-naming label ──────
    // (copy key result.sides.notUsed).

    testWidgets(
        'the "Not used" pill uses the warning tier, not Fatal red '
        '(severity is unchanged — only this citizen-facing pill '
        'changes tier)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSidesCard(
            extractionMeta: metaWithBack(
              status: 'SIDE_FAILED',
              issues: const ['SIDE_MISMATCH'],
            ),
          ),
        ),
      );

      // Two pills render (front has no data → "Not captured"); isolate the
      // back side's "Not used" pill by label.
      final pill = tester
          .widgetList<RbChip>(find.byType(RbChip))
          .firstWhere((p) => p.label == 'Not used');
      expect(pill.label, 'Not used');
      expect(pill.fill, BawariiColors.warningSoft);
      expect(pill.textColor, RefColors.warningInk);
      expect(pill.icon, Icons.remove_circle_outline);
      expect(pill.fill, isNot(BawariiColors.errorSoft));
      expect(pill.textColor, isNot(RefColors.errorInk));
    });

    testWidgets(
        'the "Not used" pill names the side in its accessible '
        'label, with the icon excluded from semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(
          DocumentSidesCard(
            extractionMeta: ExtractionMeta(
              sides: {
                'front': const SideExtractionMeta(
                  status: 'SIDE_FAILED',
                  ocrConfidence: 0.9,
                  issues: ['MRZ_VIZ_MISMATCH'],
                ),
                'back': const SideExtractionMeta(
                  status: 'SIDE_FAILED',
                  ocrConfidence: 0.9,
                  issues: ['SIDE_MISMATCH'],
                ),
              },
            ),
          ),
        ),
      );

      final pills = find.byType(SideStatusPill);
      expect(pills, findsNWidgets(2));

      final frontSemantics = tester.getSemantics(pills.at(0));
      final backSemantics = tester.getSemantics(pills.at(1));

      expect(frontSemantics.label, 'Front side not used');
      expect(backSemantics.label, 'Back side not used');
      // excludeSemantics: true on the wrapping Semantics node means the
      // icon's own (decorative) semantics never reach the tree — the
      // merged label above is the only thing a screen reader hears.
      expect(frontSemantics.label, isNot(contains('remove_circle')));

      handle.dispose();
    });

    testWidgets(
        'the explanation line is warningInk for a retake-class '
        'code, but stays errorInk for a genuine content-level fatal code',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSidesCard(
            extractionMeta: ExtractionMeta(
              sides: {
                'front': const SideExtractionMeta(
                  status: 'SIDE_FAILED',
                  ocrConfidence: 0.9,
                  issues: ['MRZ_NOT_FOUND'],
                ),
                'back': const SideExtractionMeta(
                  status: 'SIDE_FAILED',
                  ocrConfidence: 0.9,
                  issues: ['MRZ_VIZ_MISMATCH'],
                ),
              },
            ),
          ),
        ),
      );

      final fatalExplanation = tester.widget<Text>(
        find.textContaining(
          'No machine-readable zone was found on this side',
        ),
      );
      final retakeExplanation = tester.widget<Text>(
        find.textContaining('A new photo of the same card'),
      );

      expect(fatalExplanation.style?.color, RefColors.errorInk);
      expect(retakeExplanation.style?.color, RefColors.warningInk);
    });

    testWidgets(
        '"Retaken" and "Not used" share the same amber tokens but '
        'are distinguishable by word and icon, not colour', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DocumentSidesCard(
            extractionMeta: ExtractionMeta(
              sides: {
                'front': const SideExtractionMeta(
                  status: 'RETAKEN',
                  ocrConfidence: 0.9,
                ),
                'back': const SideExtractionMeta(
                  status: 'SIDE_FAILED',
                  ocrConfidence: 0.9,
                  issues: ['SIDE_MISMATCH'],
                ),
              },
            ),
          ),
        ),
      );

      final pills = tester.widgetList<RbChip>(find.byType(RbChip)).toList();
      expect(pills, hasLength(2));
      final retakenPill = pills.firstWhere((p) => p.label == 'Retaken');
      final notUsedPill = pills.firstWhere((p) => p.label == 'Not used');

      // Same colour tier — colour alone cannot tell them apart.
      expect(retakenPill.fill, notUsedPill.fill);
      expect(retakenPill.textColor, notUsedPill.textColor);
      // Different word, different icon.
      expect(retakenPill.label, isNot(notUsedPill.label));
      expect(retakenPill.icon, isNot(notUsedPill.icon));
      expect(retakenPill.icon, Icons.refresh);
      expect(notUsedPill.icon, Icons.remove_circle_outline);
    });

    // ── fixed-rank precedence, never list position ────────────

    Future<void> pumpBack(WidgetTester tester, List<String> issues) {
      return tester.pumpWidget(
        _wrap(
          DocumentSidesCard(
            extractionMeta: metaWithBack(
              status: 'SIDE_FAILED',
              issues: issues,
            ),
          ),
        ),
      );
    }

    for (final order in [
      ['SIDE_MISMATCH', 'MRZ_NOT_FOUND'],
      ['MRZ_NOT_FOUND', 'SIDE_MISMATCH'],
    ]) {
      testWidgets(
          'content-fatal MRZ_NOT_FOUND outranks retake-class SIDE_MISMATCH '
          'regardless of list order ($order)', (tester) async {
        await pumpBack(tester, order);

        expect(find.text('Rejected'), findsOneWidget);
        expect(find.text('Not used'), findsNothing);
        expect(
          find.textContaining(
            'No machine-readable zone was found on this side',
          ),
          findsOneWidget,
        );
      });
    }

    for (final order in [
      ['SIDE_MISMATCH', 'MRZ_VIZ_MISMATCH'],
      ['MRZ_VIZ_MISMATCH', 'SIDE_MISMATCH'],
    ]) {
      testWidgets(
          'MRZ_VIZ_MISMATCH outranks SIDE_MISMATCH regardless of list '
          'order ($order)', (tester) async {
        await pumpBack(tester, order);

        expect(find.text('Not used'), findsOneWidget);
        expect(
          find.textContaining('A new photo of the same card'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Both sides must come from the same card'),
          findsNothing,
        );
      });
    }

    // ── the real wire statuses, not the bare word "REJECTED" ──

    for (final wireStatus in ['REJECTED_SIDE', 'SIDE_FAILED']) {
      testWidgets(
          '$wireStatus with no catalogued fatal code reads "Rejected" for '
          'that side — only the absent front side reads "Not captured"',
          (tester) async {
        await tester.pumpWidget(
          _wrap(
            DocumentSidesCard(
              extractionMeta: metaWithBack(status: wireStatus),
            ),
          ),
        );

        // One "Rejected" (back, from wireStatus) and one "Not captured"
        // (front, which has no data at all in this fixture) — the real
        // regression is the back side wrongly reading "Not captured" too.
        expect(find.text('Rejected'), findsOneWidget);
        expect(find.text('Not captured'), findsOneWidget);
      });
    }
  });

  // ── RejectionDetails — no raw code chip for any of the 15 ───────

  group('RejectionDetails — raw-chip fallback', () {
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

    for (final code in allRejectionCodes) {
      testWidgets('$code never renders as a raw code chip', (tester) async {
        await tester.pumpWidget(
          _wrap(RejectionDetails(reasonCodes: [code])),
        );

        expect(find.byType(RbChip), findsNothing);
        expect(find.text(code), findsNothing);
        expect(find.text(rejectionMessage(code)), findsOneWidget);
      });
    }

    testWidgets(
        'an unknown code still falls back to a raw chip — the '
        'fallback path itself is not broken', (tester) async {
      await tester.pumpWidget(
        _wrap(const RejectionDetails(reasonCodes: ['SOME_FUTURE_REASON'])),
      );

      expect(find.byType(RbChip), findsOneWidget);
      expect(find.text('SOME_FUTURE_REASON'), findsOneWidget);
    });
  });
}
