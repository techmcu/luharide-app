import 'package:flutter/material.dart';

/// Hills + ride road + yellow cab (roof sign) + summit pin — matches adaptive launcher art.
class AppLogoMark extends StatelessWidget {
  final double size;

  const AppLogoMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HillsRideEmblemPainter(),
      ),
    );
  }
}

class _HillsRideEmblemPainter extends CustomPainter {
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

    final backHill = Path()
      ..moveTo(0, 56)
      ..lineTo(20, 36)
      ..lineTo(40, 48)
      ..lineTo(58, 32)
      ..lineTo(78, 44)
      ..lineTo(108, 38)
      ..lineTo(108, 108)
      ..lineTo(0, 108)
      ..close();
    canvas.drawPath(backHill, Paint()..color = const Color(0xFF34D399));

    final frontHill = Path()
      ..moveTo(0, 64)
      ..lineTo(32, 46)
      ..lineTo(54, 56)
      ..lineTo(78, 44)
      ..lineTo(100, 52)
      ..lineTo(108, 58)
      ..lineTo(108, 108)
      ..lineTo(0, 108)
      ..close();
    canvas.drawPath(frontHill, Paint()..color = const Color(0xFF0F766E));

    final road = Path()
      ..moveTo(30, 93)
      ..quadraticBezierTo(48, 72, 54, 58)
      ..quadraticBezierTo(62, 46, 84, 42);
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round,
    );

    final pin = Path()
      ..moveTo(28, 33)
      ..cubicTo(25.2, 33, 23, 35.2, 23, 38)
      ..cubicTo(23, 41.5, 28, 47.2, 28, 47.2)
      ..cubicTo(28, 47.2, 33, 41.5, 33, 38)
      ..cubicTo(33, 35.2, 30.8, 33, 28, 33)
      ..close();
    canvas.drawPath(pin, Paint()..color = const Color(0xFFC9A227));
    canvas.drawCircle(const Offset(28, 35.5), 2, Paint()..color = const Color(0xFFFFFFFF));

    final cab = Path()
      ..moveTo(43, 73)
      ..lineTo(43, 80)
      ..quadraticBezierTo(43, 82, 45, 82)
      ..lineTo(63, 82)
      ..quadraticBezierTo(65, 82, 65, 80)
      ..lineTo(65, 74)
      ..lineTo(62, 69)
      ..lineTo(46, 69)
      ..close();
    canvas.drawPath(cab, Paint()..color = const Color(0xFFFACC15));

    final roof = Path()
      ..moveTo(46.5, 67)
      ..lineTo(61.5, 67)
      ..lineTo(63, 69)
      ..lineTo(45, 69)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFFDE047));

    final sign = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(49.5, 64.5, 9, 2.5),
          const Radius.circular(0.4),
        ),
      );
    canvas.drawPath(sign, Paint()..color = const Color(0xFFDC2626));

    canvas.drawRect(const Rect.fromLTWH(50.5, 65.2, 7, 1.1), Paint()..color = const Color(0xFFFFFFFF));

    canvas.drawRect(const Rect.fromLTWH(46.5, 71, 4.5, 3), Paint()..color = const Color(0xFF0D9488));
    canvas.drawRect(const Rect.fromLTWH(57, 71, 4.5, 3), Paint()..color = const Color(0xFF0D9488));

    canvas.drawCircle(const Offset(47.5, 82), 2.6, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(const Offset(60.5, 82), 2.6, Paint()..color = const Color(0xFF1E293B));

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
