import 'package:flutter/material.dart';

/// One smooth hill + ride road + cab (roof sign) + summit pin — matches adaptive launcher art.
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

    final hill = Path()
      ..moveTo(0, 60)
      ..quadraticBezierTo(54, 34, 108, 60)
      ..lineTo(108, 108)
      ..lineTo(0, 108)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF0F766E));

    final road = Path()
      ..moveTo(30, 93)
      ..quadraticBezierTo(48, 74, 54, 62)
      ..quadraticBezierTo(60, 50, 78, 46);
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round,
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
