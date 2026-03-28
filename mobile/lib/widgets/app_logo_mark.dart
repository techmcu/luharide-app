import 'package:flutter/material.dart';

/// Single hill, L-shaped road + tail hook (no letters), larger cab — matches launcher vector.
class AppLogoMark extends StatelessWidget {
  final double size;

  const AppLogoMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HillRideEmblemPainter(),
      ),
    );
  }
}

class _HillRideEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 108.0;
    final ox = (size.width - 108 * scale) / 2;
    final oy = (size.height - 108 * scale) / 2;
    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(scale);

    const plateR = 24.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 108, 108),
        const Radius.circular(plateR),
      ),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    canvas.save();
    canvas.translate(0, -1.5);
    canvas.translate(54, 54);
    canvas.scale(0.86);
    canvas.translate(-54, -54);

    final hill = Path()
      ..moveTo(0, 60)
      ..quadraticBezierTo(54, 34, 108, 60)
      ..lineTo(108, 108)
      ..lineTo(0, 108)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF0F766E));

    final road = Path()
      ..moveTo(15, 99)
      ..quadraticBezierTo(17, 70, 18, 60)
      ..quadraticBezierTo(19, 51, 36, 49)
      ..quadraticBezierTo(58, 45, 86, 40)
      ..quadraticBezierTo(91, 44, 85, 52);
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final pin = Path()
      ..moveTo(54, 30)
      ..cubicTo(51.2, 30, 49, 32.2, 49, 35)
      ..cubicTo(49, 38.5, 54, 44.2, 54, 44.2)
      ..cubicTo(54, 44.2, 59, 38.5, 59, 35)
      ..cubicTo(59, 32.2, 56.8, 30, 54, 30)
      ..close();
    canvas.drawPath(pin, Paint()..color = const Color(0xFFC9A227));
    canvas.drawCircle(const Offset(54, 32.5), 2, Paint()..color = const Color(0xFFFFFFFF));

    final cab = Path()
      ..moveTo(39, 69)
      ..lineTo(39, 82)
      ..quadraticBezierTo(39, 85, 42.5, 85)
      ..lineTo(67.5, 85)
      ..quadraticBezierTo(71, 85, 71, 82)
      ..lineTo(71, 71.5)
      ..lineTo(65.5, 63.5)
      ..lineTo(44.5, 63.5)
      ..close();
    canvas.drawPath(cab, Paint()..color = const Color(0xFFFACC15));

    final roof = Path()
      ..moveTo(43, 62)
      ..lineTo(66.5, 62)
      ..lineTo(68.5, 63.5)
      ..lineTo(41, 63.5)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFFDE047));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(46, 58.5, 17.5, 3),
        const Radius.circular(0.35),
      ),
      Paint()..color = const Color(0xFFDC2626),
    );
    canvas.drawRect(const Rect.fromLTWH(47.5, 59.2, 14.5, 1.4), Paint()..color = const Color(0xFFFFFFFF));

    canvas.drawRect(const Rect.fromLTWH(43.5, 70.5, 6, 4), Paint()..color = const Color(0xFF0D9488));
    canvas.drawRect(const Rect.fromLTWH(59.5, 70.5, 6, 4), Paint()..color = const Color(0xFF0D9488));

    canvas.drawCircle(const Offset(45.2, 85), 3.2, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(const Offset(63.8, 85), 3.2, Paint()..color = const Color(0xFF1E293B));

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
