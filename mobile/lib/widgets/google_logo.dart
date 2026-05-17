import 'dart:math';
import 'package:flutter/material.dart';

class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final center = Offset(s / 2, s / 2);
    final outerR = s * 0.48;
    final innerR = s * 0.24;

    final path = Path();

    // Blue: right side, 0° down to 90°
    _addArcSegment(path, center, innerR, outerR, 0, pi / 2, _blue, canvas);
    // Green: 90° to 180°
    _addArcSegment(path, center, innerR, outerR, pi / 2, pi / 2, _green, canvas);
    // Yellow: 180° to 270°
    _addArcSegment(path, center, innerR, outerR, pi, pi / 2, _yellow, canvas);
    // Red: 270° to 345° (75° sweep — leaves 15° gap at upper-right)
    _addArcSegment(path, center, innerR, outerR, 3 * pi / 2, 5 * pi / 12, _red, canvas);

    // Blue horizontal bar from center to right edge
    final barTop = center.dy - (outerR - innerR) / 2;
    final barBottom = center.dy + (outerR - innerR) / 2;
    canvas.drawRect(
      Rect.fromLTRB(center.dx, barTop, center.dx + outerR, barBottom),
      Paint()..color = _blue,
    );
  }

  void _addArcSegment(Path path, Offset center, double innerR, double outerR,
      double startAngle, double sweepAngle, Color color, Canvas canvas) {
    final outerRect = Rect.fromCircle(center: center, radius: outerR);
    final innerRect = Rect.fromCircle(center: center, radius: innerR);

    final segPath = Path()
      ..arcTo(outerRect, startAngle, sweepAngle, true)
      ..arcTo(innerRect, startAngle + sweepAngle, -sweepAngle, false)
      ..close();

    canvas.drawPath(segPath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
