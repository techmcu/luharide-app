import 'package:flutter/material.dart';

/// Twin rounded peaks (cubic ridgeline), road, larger taxi, yellow pin.
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
    canvas.scale(0.9);
    canvas.translate(-54, -54);

    final hill = Path()
      ..moveTo(0, 72)
      ..cubicTo(10, 65, 22, 52, 30, 46)
      ..cubicTo(34, 42, 38, 48, 44, 50)
      ..cubicTo(48, 52, 56, 38, 74, 33)
      ..cubicTo(82, 31, 94, 44, 108, 56)
      ..lineTo(108, 108)
      ..lineTo(0, 108)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF0F766E));

    final road = Path()
      ..moveTo(16, 100)
      ..quadraticBezierTo(50, 76, 96, 54);
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFF1F5F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round,
    );

    final cab = Path()
      ..moveTo(37, 66)
      ..lineTo(37, 86)
      ..quadraticBezierTo(37, 89, 41, 89)
      ..lineTo(69, 89)
      ..quadraticBezierTo(73, 89, 73, 86)
      ..lineTo(73, 74)
      ..lineTo(68, 63.5)
      ..lineTo(42, 63.5)
      ..close();
    canvas.drawPath(cab, Paint()..color = const Color(0xFFFACC15));

    final roof = Path()
      ..moveTo(41, 61)
      ..lineTo(69, 61)
      ..lineTo(71, 63.5)
      ..lineTo(39, 63.5)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFEAB308));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(44.5, 57.5, 21, 3),
        const Radius.circular(0.35),
      ),
      Paint()..color = const Color(0xFFDC2626),
    );

    canvas.drawRect(const Rect.fromLTWH(42, 71.5, 6.5, 4.5), Paint()..color = const Color(0xFF0F766E));
    canvas.drawRect(const Rect.fromLTWH(59.5, 71.5, 6.5, 4.5), Paint()..color = const Color(0xFF0F766E));

    canvas.drawCircle(const Offset(44.5, 89.5), 3.5, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(const Offset(62.5, 89.5), 3.5, Paint()..color = const Color(0xFF1E293B));

    final pin = Path()
      ..moveTo(54, 21.5)
      ..cubicTo(48.2, 21.5, 42.8, 27, 42.8, 34)
      ..cubicTo(42.8, 41.5, 54, 52.5, 54, 52.5)
      ..cubicTo(54, 52.5, 65.2, 41.5, 65.2, 34)
      ..cubicTo(65.2, 27, 59.8, 21.5, 54, 21.5)
      ..close();
    canvas.drawPath(pin, Paint()..color = const Color(0xFFFACC15));
    canvas.drawCircle(const Offset(54, 28.8), 3.8, Paint()..color = const Color(0xFFFFFFFF));

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
