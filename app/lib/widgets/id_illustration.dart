import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// The document + liveness illustration shown on S2 Pre-Capture and the
/// Arming state.
class IdIllustration extends StatelessWidget {
  const IdIllustration({
    super.key,
    this.liveness = true,
    this.scale = 1,
    this.dim = false,
  });

  final bool liveness;
  final double scale;
  final bool dim;

  double _s(double n) => n * scale;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.6 : 1,
      child: SizedBox(
        width: _s(180),
        height: _s(124),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: _s(12),
              width: _s(136),
              height: _s(90),
              child: Container(
                padding: EdgeInsets.all(_s(12)),
                decoration: BoxDecoration(
                  color: BawariiColors.trustSoft,
                  border: Border.all(color: BawariiColors.trust, width: 1.5),
                  borderRadius: BorderRadius.circular(BawariiRadii.r10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(0.72, 0.45),
                    SizedBox(height: _s(7)),
                    _bar(0.48, 0.45),
                    SizedBox(height: _s(7)),
                    _bar(0.60, 0.45),
                    SizedBox(height: _s(7)),
                    _bar(0.38, 0.3),
                  ],
                ),
              ),
            ),
            if (liveness)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: _s(58),
                  height: _s(72),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BawariiColors.paper,
                    border: Border.all(color: BawariiColors.volt, width: 1.5),
                    borderRadius: BorderRadius.circular(_s(29)),
                  ),
                  child: Icon(
                    Icons.face_outlined,
                    size: _s(28),
                    color: BawariiColors.voltDeep,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double widthFraction, double opacity) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      alignment: Alignment.centerLeft,
      child: Container(
        height: _s(5),
        decoration: BoxDecoration(
          color: BawariiColors.trust.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
