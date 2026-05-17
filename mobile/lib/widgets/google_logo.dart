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
    final radius = s * 0.45;
    final strokeWidth = s * 0.2;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Draw arcs (angles in radians, 0 = 3 o'clock, clockwise)
    // Blue: top-right (from -45deg to +45deg)
    paint.color = _blue;
    canvas.drawArc(rect, -pi / 4, pi / 2, false, paint);

    // Green: bottom-right (from +45deg to +135deg)
    paint.color = _green;
    canvas.drawArc(rect, pi / 4, pi / 2, false, paint);

    // Yellow: bottom-left (from +135deg to +225deg)
    paint.color = _yellow;
    canvas.drawArc(rect, 3 * pi / 4, pi / 2, false, paint);

    // Red: top-left (from +225deg to +315deg = -45deg)
    paint.color = _red;
    canvas.drawArc(rect, 5 * pi / 4, pi / 2, false, paint);

    // Horizontal bar of the "G" (blue)
    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    final barHeight = strokeWidth * 0.75;
    final barLeft = center.dx;
    final barTop = center.dy - barHeight / 2;
    canvas.drawRect(
      Rect.fromLTWH(barLeft, barTop, radius + strokeWidth / 2, barHeight),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
