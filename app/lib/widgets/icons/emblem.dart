import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// The Bawarii emblem mark: a geometric line-drawing
/// derived from the e-Tazkira's own emblem — a tapered pulpit/mihrab
/// silhouette inside a circle. Line art only, single colour, no fill.
class Emblem extends StatelessWidget {
  const Emblem({super.key, this.size = 28, this.color = BawariiColors.volt});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _EmblemPainter(color: color)),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinates below are lifted directly from the design's 28x28 SVG
    // viewBox (`ref-s1-s2.jsx` `Emblem`), scaled to the render size.
    final scale = size.width / 28;
    Offset p(double x, double y) => Offset(x * scale, y * scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(p(14, 14), 12.4 * scale, paint);

    final pulpit = Path()
      ..moveTo(p(14, 5.4).dx, p(14, 5.4).dy)
      ..lineTo(p(17.4, 9.6).dx, p(17.4, 9.6).dy)
      ..lineTo(p(17.4, 18.8).dx, p(17.4, 18.8).dy)
      ..lineTo(p(10.6, 18.8).dx, p(10.6, 18.8).dy)
      ..lineTo(p(10.6, 9.6).dx, p(10.6, 9.6).dy)
      ..close();
    canvas.drawPath(pulpit, paint);

    canvas.drawLine(p(11.4, 18.8), p(16.6, 18.8), paint);
    canvas.drawLine(p(12.6, 22.2), p(15.4, 22.2), paint);
    canvas.drawLine(p(14, 9.6), p(14, 15), paint);
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter oldDelegate) =>
      oldDelegate.color != color;
}
