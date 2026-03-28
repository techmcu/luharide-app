import 'dart:math' as math;
import 'package:flutter/material.dart';

/// LuhaRide mark: layered hills (Uttarakhand), mountain road, taxi, destination pin.
/// No text — journey + local ride meaning. Rich gradients in-app; XML launcher uses flat fills.
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
        painter: _LuhaRideMarkPainter(showPlate: showPlate, breathe: 1),
      ),
    );
  }
}

/// Subtle “alive” scale pulse — use on login / splash only (saves battery elsewhere).
class AppLogoMarkAnimated extends StatefulWidget {
  const AppLogoMarkAnimated({
    super.key,
    this.size = 120,
    this.showPlate = true,
  });

  final double size;
  final bool showPlate;

  @override
  State<AppLogoMarkAnimated> createState() => _AppLogoMarkAnimatedState();
}

class _AppLogoMarkAnimatedState extends State<AppLogoMarkAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final breathe = 1 + 0.028 * math.sin(_c.value * math.pi * 2);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _LuhaRideMarkPainter(showPlate: widget.showPlate, breathe: breathe),
          ),
        );
      },
    );
  }
}

class _LuhaRideMarkPainter extends CustomPainter {
  _LuhaRideMarkPainter({required this.showPlate, required this.breathe});

  final bool showPlate;
  final double breathe;

  static const _kTeal = Color(0xFF0F766E);
  static const _kTealDeep = Color(0xFF0D5C55);
  static const _kTealDark = Color(0xFF134E4A);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 108.0;
    final ox = (size.width - 108 * scale) / 2;
    final oy = (size.height - 108 * scale) / 2;
    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(scale);

    if (showPlate) {
      final plate = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 108, 108),
        const Radius.circular(24),
      );
      canvas.drawRRect(
        plate,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
          ).createShader(const Rect.fromLTWH(0, 0, 108, 108)),
      );
    }

    canvas.save();
    canvas.translate(54, 54);
    canvas.scale(0.76 * breathe);
    canvas.translate(-54, -54);
    canvas.translate(0, -8);

    _drawSky(canvas);
    _drawFarRange(canvas);
    _drawSnowHints(canvas);
    _drawNearHill(canvas);
    _drawRoad(canvas);
    _drawCabShadow(canvas);
    _drawCab(canvas);
    _drawPin(canvas);

    canvas.restore();
    canvas.restore();
  }

  void _drawSky(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, 108, 48);
    final g = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFB2DFDB).withValues(alpha: 0.95),
        const Color(0xFFE0F2F1).withValues(alpha: 0.5),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0, 0.55, 1],
    );
    canvas.drawRect(rect, Paint()..shader = g.createShader(rect));
  }

  void _drawFarRange(Canvas canvas) {
    final far = Path()
      ..moveTo(0, 78)
      ..cubicTo(14, 68, 26, 66, 38, 61)
      ..cubicTo(50, 55, 62, 57, 74, 50)
      ..cubicTo(86, 45, 98, 52, 108, 46)
      ..lineTo(108, 108)
      ..lineTo(0, 108)
      ..close();
    final farRect = far.getBounds();
    canvas.drawPath(
      far,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kTealDark, _kTealDeep],
        ).createShader(farRect.inflate(4)),
    );
  }

  void _drawSnowHints(Canvas canvas) {
    final cap = Path()
      ..moveTo(72, 49)
      ..cubicTo(76, 44, 82, 43, 88, 46)
      ..cubicTo(84, 50, 78, 52, 72, 49)
      ..close();
    canvas.drawPath(cap, Paint()..color = const Color(0xFFE0F7FA).withValues(alpha: 0.85));
    final cap2 = Path()
      ..moveTo(28, 60)
      ..cubicTo(32, 56, 38, 55, 42, 58)
      ..cubicTo(38, 62, 32, 63, 28, 60)
      ..close();
    canvas.drawPath(cap2, Paint()..color = const Color(0xFFF0FDFA).withValues(alpha: 0.7));
  }

  void _drawNearHill(Canvas canvas) {
    final hill = Path()
      ..moveTo(0, 74)
      ..cubicTo(8, 69, 14, 62, 22, 56)
      ..cubicTo(28, 52, 34, 54, 38, 50)
      ..cubicTo(42, 46, 44, 42, 46, 40)
      ..cubicTo(48, 41, 52, 46, 56, 47)
      ..cubicTo(60, 46, 66, 38, 72, 36)
      ..cubicTo(78, 34, 86, 40, 94, 48)
      ..cubicTo(100, 52, 105, 56, 108, 59)
      ..lineTo(108, 108)
      ..lineTo(0, 108)
      ..close();
    final b = hill.getBounds();
    canvas.drawPath(
      hill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF14B8A6),
            _kTeal,
            const Color(0xFF0D9488),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(b.inflate(6)),
    );
    final ridge = Path()
      ..moveTo(18, 58)
      ..quadraticBezierTo(46, 42, 78, 38);
    canvas.drawPath(
      ridge,
      Paint()
        ..color = const Color(0xFF5EEAD4).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawRoad(Canvas canvas) {
    final road = Path()
      ..moveTo(12, 102)
      ..quadraticBezierTo(50, 77, 100, 54);
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFF475569)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFF1F5F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final dash = Path()
      ..moveTo(22, 96)
      ..quadraticBezierTo(52, 74, 88, 58);
    canvas.drawPath(
      dash,
      Paint()
        ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCabShadow(Canvas canvas) {
    final shadow = Path()
      ..addOval(const Rect.fromLTWH(39.5, 95, 29, 4.8));
    canvas.drawPath(
      shadow,
      Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
  }

  /// Side-profile taxi (left = front bumper, right = rear) — not head-on.
  void _drawCab(Canvas canvas) {
    final hull = Path()
      ..moveTo(42, 93.5)
      ..lineTo(66, 93.5)
      ..lineTo(66, 70.5)
      ..cubicTo(65.5, 62.5, 61.2, 57.8, 54, 56.2)
      ..cubicTo(46.8, 57.8, 42.5, 62.5, 42, 70.5)
      ..close();

    final hullBounds = hull.getBounds();
    canvas.drawPath(
      hull,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFFFEF08A),
            Color(0xFFFACC15),
            Color(0xFFEAB308),
            Color(0xFFD97706),
          ],
          stops: const [0, 0.3, 0.65, 1],
        ).createShader(hullBounds.inflate(1.5)),
    );

    canvas.drawPath(
      hull,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..color = const Color(0xFFB45309).withValues(alpha: 0.4),
    );

    // Roof taxi lamp
    final lampOuter = RRect.fromRectAndRadius(
      const Rect.fromLTWH(49.2, 47.8, 9.6, 5.4),
      const Radius.circular(1),
    );
    canvas.drawRRect(lampOuter, Paint()..color = const Color(0xFF171717));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(49.8, 48.5, 8.4, 3.4),
        const Radius.circular(0.5),
      ),
      Paint()..color = const Color(0xFFFBBF24),
    );

    // Side glass (one cabin block)
    final glass = RRect.fromRectAndRadius(
      const Rect.fromLTWH(44.5, 59.2, 19, 12.2),
      const Radius.circular(1.8),
    );
    canvas.drawRRect(
      glass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFCCFBF1),
            const Color(0xFF0F766E),
            const Color(0xFF134E4A),
          ],
        ).createShader(glass.outerRect),
    );
    canvas.drawRRect(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.45),
    );

    // Door / B-pillar (side view)
    canvas.drawLine(
      const Offset(54, 60),
      const Offset(54, 70.5),
      Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.2)
        ..strokeWidth = 0.65,
    );

    // Front headlamp (left / nose)
    canvas.drawCircle(const Offset(41.6, 75.2), 2.1, Paint()..color = const Color(0xFFFEFCE8));
    canvas.drawCircle(const Offset(41.3, 74.8), 0.9, Paint()..color = Colors.white);

    _miniWheel(canvas, const Offset(47.5, 94.35));
    _miniWheel(canvas, const Offset(60.5, 94.35));
  }

  void _miniWheel(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 5.1, Paint()..color = const Color(0xFF0F172A));
    canvas.drawCircle(c, 4.5, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(c, 2.7, Paint()..color = const Color(0xFF64748B));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 2.5),
      -2.5,
      1.1,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75,
    );
  }

  void _drawPin(Canvas canvas) {
    const cx = 54.0;
    const top = 20.0;
    final pinPath = Path()
      ..moveTo(cx, top)
      ..cubicTo(46.5, top, 40.5, 26.2, 40.5, 33.5)
      ..cubicTo(40.5, 41.5, cx, 53.2, cx, 53.2)
      ..cubicTo(cx, 53.2, 67.5, 41.5, 67.5, 33.5)
      ..cubicTo(67.5, 26.2, 61.5, top, cx, top)
      ..close();
    final pinRect = pinPath.getBounds();
    canvas.drawPath(
      pinPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.65),
          radius: 1.15,
          colors: const [
            Color(0xFFFEF08A),
            Color(0xFFFACC15),
            Color(0xFFD97706),
            Color(0xFFB45309),
          ],
          stops: const [0, 0.35, 0.72, 1],
        ).createShader(pinRect.inflate(3)),
    );
    canvas.drawPath(
      pinPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85
        ..color = const Color(0xFFB45309).withValues(alpha: 0.45),
    );

    final hole = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0)],
      ).createShader(Rect.fromCircle(center: Offset(cx, 29.5), radius: 4.1));
    canvas.drawCircle(const Offset(cx, 29.5), 4.1, hole);
    canvas.drawCircle(
      const Offset(cx, 28.6),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _LuhaRideMarkPainter oldDelegate) =>
      oldDelegate.showPlate != showPlate || oldDelegate.breathe != breathe;
}
