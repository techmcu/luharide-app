import 'package:flutter/material.dart';

/// Two soft mountain peaks + saddle, road, taxi, yellow pin (matches launcher).
class AppLogoMark extends StatelessWidget {
  final double size;

  const AppLogoMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TwinPeakEmblemPainter(),
      ),
    );
  }
}

class _TwinPeakEmblemPainter extends CustomPainter {
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
    canvas.translate(0, -1);
    canvas.translate(54, 54);
    canvas.scale(0.88);
    canvas.translate(-54, -54);

    final hill = Path()
      ..moveTo(0, 65)
      ..quadraticBezierTo(14, 54, 28, 44)
      ..quadraticBezierTo(34, 37, 42, 46)
      ..quadraticBezierTo(48, 50, 56, 42)
      ..quadraticBezierTo(68, 32, 80, 40)
      ..quadraticBezierTo(92, 50, 108, 58)
      ..lineTo(108, 108)
      ..lineTo(0, 108)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF0F766E));

    final road = Path()
      ..moveTo(22, 99)
      ..quadraticBezierTo(54, 72, 90, 50);
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFF1F5F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    final cab = Path()
      ..moveTo(44, 71)
      ..lineTo(44, 81.5)
      ..quadraticBezierTo(44, 83.5, 46.5, 83.5)
      ..lineTo(64.5, 83.5)
      ..quadraticBezierTo(67, 83.5, 67, 81.5)
      ..lineTo(67, 73)
      ..lineTo(64, 67.5)
      ..lineTo(47.5, 67.5)
      ..close();
    canvas.drawPath(cab, Paint()..color = const Color(0xFFFACC15));

    final roof = Path()
      ..moveTo(47.5, 64.5)
      ..lineTo(63.5, 64.5)
      ..lineTo(65, 67)
      ..lineTo(46, 67)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFEAB308));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(50, 61.5, 11, 2.3),
        const Radius.circular(0.25),
      ),
      Paint()..color = const Color(0xFFDC2626),
    );

    canvas.drawRect(const Rect.fromLTWH(47, 72, 4.5, 3.5), Paint()..color = const Color(0xFF0F766E));
    canvas.drawRect(const Rect.fromLTWH(59.5, 72, 4.5, 3.5), Paint()..color = const Color(0xFF0F766E));

    canvas.drawCircle(const Offset(47.9, 84), 2.8, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(const Offset(60.1, 84), 2.8, Paint()..color = const Color(0xFF1E293B));

    final pin = Path()
      ..moveTo(54, 23)
      ..cubicTo(48.5, 23, 43.5, 28, 43.5, 34.5)
      ..cubicTo(43.5, 42, 54, 53.5, 54, 53.5)
      ..cubicTo(54, 53.5, 64.5, 42, 64.5, 34.5)
      ..cubicTo(64.5, 28, 59.5, 23, 54, 23)
      ..close();
    canvas.drawPath(pin, Paint()..color = const Color(0xFFFACC15));
    canvas.drawCircle(const Offset(54, 30), 3.5, Paint()..color = const Color(0xFFFFFFFF));

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
