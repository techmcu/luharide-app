import 'package:flutter/material.dart';

/// LuhaRide launcher-style emblem: white plate, gold ring, teal pin + car — static (matches APK adaptive icon).
class AppLogoMark extends StatelessWidget {
  final double size;

  const AppLogoMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LauncherEmblemPainter(),
      ),
    );
  }
}

class _LauncherEmblemPainter extends CustomPainter {
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

    canvas.drawCircle(
      const Offset(54, 54),
      33,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFC9A227)
        ..strokeCap = StrokeCap.round,
    );

    final pin = Path()
      ..moveTo(54, 27.5)
      ..cubicTo(50.9, 27.5, 48.4, 29.9, 48.4, 32.9)
      ..cubicTo(48.4, 36.7, 54, 43.7, 54, 43.7)
      ..cubicTo(54, 43.7, 59.6, 36.7, 59.6, 32.9)
      ..cubicTo(59.6, 29.9, 57.1, 27.5, 54, 27.5)
      ..close();
    canvas.drawPath(pin, Paint()..color = const Color(0xFF0F766E));
    canvas.drawCircle(const Offset(54, 30.5), 2.3, Paint()..color = const Color(0xFFFFFFFF));

    final car = Path()
      ..moveTo(31.5, 61.5)
      ..lineTo(31.5, 71.5)
      ..quadraticBezierTo(31.5, 74.5, 34.5, 74.5)
      ..lineTo(73.5, 74.5)
      ..quadraticBezierTo(76.5, 74.5, 76.5, 71.5)
      ..lineTo(76.5, 61.5)
      ..quadraticBezierTo(76.5, 58.5, 73.5, 58.5)
      ..lineTo(69.5, 58.5)
      ..lineTo(66.5, 52.5)
      ..lineTo(41.5, 52.5)
      ..lineTo(38.5, 58.5)
      ..lineTo(34.5, 58.5)
      ..quadraticBezierTo(31.5, 58.5, 31.5, 61.5)
      ..close();
    canvas.drawPath(car, Paint()..color = const Color(0xFF0F766E));

    final wind = Path()
      ..moveTo(43, 59.5)
      ..lineTo(45.5, 59.5)
      ..lineTo(48, 56.5)
      ..lineTo(60, 56.5)
      ..lineTo(62.5, 59.5)
      ..lineTo(65, 59.5)
      ..lineTo(63, 62.5)
      ..lineTo(45, 62.5)
      ..close();
    canvas.drawPath(wind, Paint()..color = const Color(0xFF99F6E4));

    canvas.drawCircle(const Offset(39, 74.5), 4.8, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(const Offset(69, 74.5), 4.8, Paint()..color = const Color(0xFF1E293B));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
