import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../../models/issue_severity.dart';
import '../../models/reference_result.dart';
import '../../theme/ref_colors.dart';
import '../icons/document_side_icons.dart';
import '../primitives/rb_card.dart';
import '../primitives/rb_chip.dart';
import '../primitives/section_label.dart';

/// DocumentSidesCard — iconic side tiles, never
/// thumbnails: the SDK uploads images directly to the platform and never
/// returns them to the host app, so the card names that limitation instead
/// of hiding it.
class DocumentSidesCard extends StatelessWidget {
  const DocumentSidesCard({super.key, this.extractionMeta});

  final ExtractionMeta? extractionMeta;

  @override
  Widget build(BuildContext context) {
    final front = extractionMeta?.sides['front'];
    final back = extractionMeta?.sides['back'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Document sides'),
        RbCard(
          child: Column(
            children: [
              _SideRow(
                glyph: DocumentSideGlyph.front,
                name: 'Front',
                description:
                    'Arabic-script fields · Dari · Pashto · Solar Hijri dates',
                status: front?.status,
                issues: front?.issues ?? const [],
              ),
              const Divider(height: 24, color: BawariiColors.hairline),
              _SideRow(
                glyph: DocumentSideGlyph.back,
                name: 'Back',
                description: 'Latin fields + MRZ · ICAO 9303 TD1',
                status: back?.status,
                issues: back?.issues ?? const [],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: BawariiColors.hairline),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: BawariiColors.ink50,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Document images are never returned to your app. Only '
                      'extracted fields are.',
                      style: BawariiTextStyles.fine.copyWith(
                        color: BawariiColors.ink70,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The side's deciding fatal code, by a fixed rank — never by position in
/// [issues] (a "first fatal code" rule would make the
/// pill depend on issue order). Pipeline order: the earliest stage
/// that failed wins, so any content-fatal code outranks either retake-class
/// code and the pill reads `Rejected`. In practice the two kinds do not
/// co-occur on one side, but this makes the choice deterministic either way.
const _fatalIssueCodesByPrecedence = [
  'IMAGE_TOO_LARGE',
  'IMAGE_DECODE_ERROR',
  'MRZ_NOT_FOUND',
  'MRZ_VIZ_MISMATCH',
  'SIDE_MISMATCH',
];

String? _decidingFatalCode(List<String> issues) {
  for (final code in _fatalIssueCodesByPrecedence) {
    if (issues.contains(code)) return code;
  }
  return null;
}

class _SideRow extends StatelessWidget {
  const _SideRow({
    required this.glyph,
    required this.name,
    required this.description,
    required this.status,
    required this.issues,
  });

  final DocumentSideGlyph glyph;
  final String name;
  final String description;
  final String? status;
  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final fatalCode = _decidingFatalCode(issues);
    final sideStatus = _resolveStatus(status, fatalCode);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: BawariiColors.trustSoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: DocumentSideIcon(
              side: glyph,
              size: 20,
              color: BawariiColors.trust,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toUpperCase(),
                style: BawariiTextStyles.fine.copyWith(
                  color: BawariiColors.ink70,
                  letterSpacing: 0.08 * 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: BawariiTextStyles.bodySmall.copyWith(
                  color: BawariiColors.ink70,
                ),
              ),
              if (fatalCode != null) ...[
                const SizedBox(height: 4),
                Text(
                  plainLanguageForIssue(fatalCode) ?? fatalCode,
                  style: BawariiTextStyles.fine.copyWith(
                    // a retake-class code's
                    // explanation reads in the same amber tier as its pill
                    // above — content-level fatal codes (a genuine
                    // rejection) keep errorInk.
                    color: retakeClassIssueCodes.contains(fatalCode)
                        ? RefColors.warningInk
                        : RefColors.errorInk,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SideStatusPill(status: sideStatus, sideName: name),
        ),
      ],
    );
  }

  SideStatusKind _resolveStatus(String? rawStatus, String? fatalCode) {
    if (fatalCode != null) {
      // a retake-class refusal means this side was never
      // used, not that the side's content was found to be fraudulent —
      // "Rejected" reads as an accusation. "Rejected" stays reserved for a
      // side whose own reported status is genuinely REJECTED, below.
      return retakeClassIssueCodes.contains(fatalCode)
          ? SideStatusKind.notUsed
          : SideStatusKind.rejected;
    }
    // the per-side wire status is never the
    // bare word "REJECTED" — the server sends REJECTED_SIDE or SIDE_FAILED
    // document_sides vocabulary). Matching only the literal
    // "REJECTED" left a genuinely refused side with no catalogued fatal
    // code silently showing "Not captured", which reads as "nothing was
    // ever submitted" rather than "this was refused". SIDE_PROCESSING is
    // an in-flight-only status that should never reach a terminal result
    // screen; it falls through to the same safe default as an
    // absent/unrecognised value below rather than inventing an
    // un-speced "processing" pill.
    return switch (rawStatus?.toUpperCase()) {
      'ACCEPTED' => SideStatusKind.accepted,
      'REJECTED' || 'REJECTED_SIDE' || 'SIDE_FAILED' => SideStatusKind.rejected,
      'RETAKEN' => SideStatusKind.retaken,
      _ => SideStatusKind.notCaptured,
    };
  }
}
