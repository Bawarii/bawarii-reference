import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reference-app-local type styles used by this app,
/// plus a same-app workaround for a font-family problem in `bawarii_ui`.
///
/// **workaround:** `BawariiTextStyles.mono` / `monoSmall` in
/// `package:bawarii_ui` declare `fontFamily: 'IBMPlexMono'` with no matching
/// `fonts:` asset registration anywhere in that package, so Flutter silently
/// falls back to the platform default monospace face — every ID, date, MRZ
/// line, and JSON block in the app has been rendering in the wrong font.
/// The real fix belongs in `bawarii_ui` (out of scope here — this app does
/// not modify that package). [RefTextStyles.mono] / [monoSmall] below are drop-in
/// replacements that render IBM Plex Mono correctly via `google_fonts`,
/// used throughout this app's screens in place of the broken
/// `bawarii_ui` originals.
abstract final class RefTextStyles {
  /// 26 / 800 / +0.02em — the verdict word on the result hero card.
  static TextStyle get verdictLabel => GoogleFonts.manrope(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.02 * 26,
    height: 1.2,
    color: BawariiColors.ink,
  );

  /// 22 / 700, tabular — the three ExtractionQualityCard headline metrics.
  static TextStyle get metricValue => GoogleFonts.manrope(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: BawariiColors.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// IBM Plex Mono, 16 / 500, tabular — IDs, dates, confidence values.
  /// Corrected replacement for the broken `BawariiTextStyles.mono`.
  static TextStyle get mono => GoogleFonts.ibmPlexMono(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.04,
    height: 1.4,
    color: BawariiColors.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// IBM Plex Mono, 13 / 500, tabular — session/reference IDs, MRZ lines.
  /// Corrected replacement for the broken `BawariiTextStyles.monoSmall`.
  static TextStyle get monoSmall => GoogleFonts.ibmPlexMono(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.08,
    height: 1.4,
    color: BawariiColors.ink70,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// IBM Plex Mono, 11 / 500 — raw JSON escape hatch only.
  static TextStyle get monoTiny => GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: BawariiColors.ink70,
  );
}
