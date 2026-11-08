import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/painting.dart';

import '../theme/ref_colors.dart';

/// The three confidence bands a field's OCR confidence resolves to
/// . Amber-scaled, never red — a low-confidence
/// field on an otherwise-approved result is not an error.
enum ConfidenceTier { high, check, review }

/// Resolves a raw confidence value (0.0–1.0) to its [ConfidenceTier].
///
///   ≥ 0.90            → [ConfidenceTier.high]
///   0.70 – 0.899...   → [ConfidenceTier.check]
///   < 0.70            → [ConfidenceTier.review]
ConfidenceTier tierOfConfidence(double confidence) {
  if (confidence >= 0.90) return ConfidenceTier.high;
  if (confidence >= 0.70) return ConfidenceTier.check;
  return ConfidenceTier.review;
}

/// The client-tier field row's 4dp leading rail colour.
///
/// High confidence deliberately does **not** use `success` green here —
/// "silence means confident": a near-invisible
/// `trustSoft` rail keeps high-confidence rows optically quiet so the
/// flagged rows are the only ones that read as coloured.
Color railColorForTier(ConfidenceTier tier) {
  return switch (tier) {
    ConfidenceTier.review => BawariiColors.warning,
    ConfidenceTier.check => RefColors.warningMid,
    ConfidenceTier.high => BawariiColors.trustSoft,
  };
}

/// The developer-panel / field-detail-sheet confidence bar fill colour
/// . Unlike [railColorForTier], `success` green *is* used for High
/// here — this audience is technical, the raw number is on screen, and
/// there is no verdict adjacency for the colour to contradict.
Color devConfidenceFillColorForTier(ConfidenceTier tier) {
  return switch (tier) {
    ConfidenceTier.review => BawariiColors.warning,
    ConfidenceTier.check => RefColors.warningMid,
    ConfidenceTier.high => BawariiColors.success,
  };
}
