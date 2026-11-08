import 'package:flutter/material.dart';

/// Distinct, iconic front/back document-side glyphs:
/// "the clearest possible statement that the product knows the document has
/// two structurally different sides". Front: a card glyph with a portrait
/// block and label lines. Back: a card glyph with MRZ-style lines.
enum DocumentSideGlyph { front, back }

class DocumentSideIcon extends StatelessWidget {
  const DocumentSideIcon({
    super.key,
    required this.side,
    this.size = 20,
    this.color = Colors.black,
    this.strokeWidth = 1.9,
  });

  final DocumentSideGlyph side;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DocumentSideIconPainter(
          side: side,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _DocumentSideIconPainter extends CustomPainter {
  _DocumentSideIconPainter({
    required this.side,
    required this.color,
    required this.strokeWidth,
  });

  final DocumentSideGlyph side;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    Offset p(double x, double y) => Offset(x * scale, y * scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cardRect = Rect.fromPoints(p(2.8, 5.2), p(21.2, 18.8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, Radius.circular(2.4 * scale)),
      paint,
    );

    if (side == DocumentSideGlyph.front) {
      // Portrait block + label lines (Arabic-script side).
      final portraitRect = Rect.fromPoints(p(5.6, 8.2), p(10.8, 14.6));
      canvas.drawRRect(
        RRect.fromRectAndRadius(portraitRect, Radius.circular(1 * scale)),
        paint,
      );
      canvas.drawLine(p(13.6, 9.2), p(18, 9.2), paint);
      canvas.drawLine(p(13.6, 12), p(18, 12), paint);
      canvas.drawLine(p(13.6, 14.8), p(16.4, 14.8), paint);
    } else {
      // Three MRZ-style lines (Latin + machine-readable zone side).
      canvas.drawLine(p(5.6, 8.4), p(12, 8.4), paint);
      canvas.drawLine(p(5.6, 11.6), p(18.4, 11.6), paint);
      canvas.drawLine(p(5.6, 14), p(18.4, 14), paint);
      canvas.drawLine(p(5.6, 16.4), p(14, 16.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DocumentSideIconPainter oldDelegate) =>
      oldDelegate.side != side ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
