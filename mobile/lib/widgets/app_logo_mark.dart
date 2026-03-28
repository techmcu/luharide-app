import 'package:flutter/material.dart';

/// Natural-style ridgeline, road, taxi, pin. Matches [ic_launcher_foreground.xml].
class AppLogoMark extends StatelessWidget {
  final double size;
  final bool showPlate;

  const AppLogoMark({
    super.key,
    this.size = 40,
    this.showPlate = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TwinPeakEmblemPainter(showPlate: showPlate),
      ),
    );
  }
}

class _TwinPeakEmblemPainter extends CustomPainter {
  _TwinPeakEmblemPainter({required this.showPlate});

  final bool showPlate;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 108.0;
    final ox = (size.width - 108 * scale) / 2;
    final oy = (size.height - 108 * scale) / 2;
    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(scale);

    if (showPlate) {
      const plateR = 24.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 108, 108),
          const Radius.circular(plateR),
        ),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    canvas.save();
    canvas.translate(54, 54);
    canvas.scale(0.76);
    canvas.translate(-54, -54);
    canvas.translate(0, -8);

    final hill = Path()
      ..moveTo(0, 73)
      ..cubicTo(6, 68, 12, 60, 20, 54)
      ..cubicTo(26, 50, 32, 52, 36, 48)
      ..cubicTo(40, 45, 42, 41, 44, 39)
      ..cubicTo(46, 40, 50, 46, 54, 47)
      ..cubicTo(58, 46, 64, 38, 70, 36)
      ..cubicTo(76, 34, 84, 40, 92, 48)
      ..cubicTo(98, 52, 103, 56, 108, 59)
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
      ..moveTo(33, 63)
      ..lineTo(33, 91)
      ..quadraticBezierTo(33, 95, 38.5, 95)
      ..lineTo(72.5, 95)
      ..quadraticBezierTo(78, 95, 78, 91)
      ..lineTo(78, 75)
      ..lineTo(72, 60.5)
      ..lineTo(40, 60.5)
      ..close();
    canvas.drawPath(cab, Paint()..color = const Color(0xFFFACC15));

    final roof = Path()
      ..moveTo(37.5, 57)
      ..lineTo(73.5, 57)
      ..lineTo(76, 60.5)
      ..lineTo(35, 60.5)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFEAB308));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(41, 53.5, 29, 3.3),
        const Radius.circular(0.35),
      ),
      Paint()..color = const Color(0xFFDC2626),
    );

    canvas.drawRect(const Rect.fromLTWH(39.5, 69.5, 8, 5.5), Paint()..color = const Color(0xFF0F766E));
    canvas.drawRect(const Rect.fromLTWH(60.5, 69.5, 8, 5.5), Paint()..color = const Color(0xFF0F766E));

    canvas.drawCircle(const Offset(47.5, 94.5), 4, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(const Offset(64.5, 94.5), 4, Paint()..color = const Color(0xFF1E293B));

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
  bool shouldRepaint(covariant _TwinPeakEmblemPainter oldDelegate) =>
      oldDelegate.showPlate != showPlate;
}
