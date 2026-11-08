import 'package:flutter/painting.dart' show Color;

/// Reference-app-local colour tokens used by this app.
///
/// These are **not** added to `package:bawarii_ui` — that package is owned by
/// the Bawarii platform team and is out of scope for this app.
/// Everything else (ink/trust/success/warning/error base tokens) already lives in
/// [BawariiColors] and is reused as-is.
abstract final class RefColors {
  /// Text-on-tint ink for success surfaces (e.g. `successSoft` fills).
  /// `BawariiColors.success` (#2D7A6B) does not meet 4.5:1 on `successSoft`;
  /// this darker ink does.
  static const successInk = Color(0xFF1C5348);

  /// Text-on-tint ink for warning surfaces (e.g. `warningSoft` fills).
  static const warningInk = Color(0xFF6E4A12);

  /// Text-on-tint ink for error surfaces (e.g. `errorSoft` fills).
  static const errorInk = Color(0xFF8A2436);

  /// The "Check" confidence tier's rail/segment colour — a muted amber sits
  /// between `trustSoft` (High) and `warning` (Review) on the confidence
  /// scale so a mid-confidence field is visually distinct from both.
  static const warningMid = Color(0xFFD8B37E);
}
