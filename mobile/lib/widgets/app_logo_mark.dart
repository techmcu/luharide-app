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
      ..addOval(const Rect.fromLTWH(30.5, 95.1, 47, 4.5));
    canvas.drawPath(
      shadow,
      Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
  }

  /// Variant **B**: low wedge sedan taxi — long hood, sharp windshield, wide track (demo lock).
  void _drawCab(Canvas canvas) {
    // Low-wedge sedan taxi (variant B): hood → cabin → deck, X compressed ~0.82 about center 54.
    final hull = Path()
      ..moveTo(32.9, 95.15)
      ..lineTo(32.9, 86.5)
      ..quadraticBezierTo(32.45, 78.0, 36.6, 72.5)
      ..quadraticBezierTo(41.1, 65.0, 46.0, 60.5)
      ..lineTo(51.7, 56.0)
      ..quadraticBezierTo(57.8, 53.5, 64.0, 54.8)
      ..quadraticBezierTo(69.8, 56.0, 71.9, 61.0)
      ..lineTo(74.3, 70.0)
      ..lineTo(75.1, 80.0)
      ..lineTo(75.1, 95.15)
      ..lineTo(67.3, 95.15)
      ..quadraticBezierTo(64.9, 88.5, 59.8, 88.5)
      ..quadraticBezierTo(54.75, 88.5, 52.2, 95.15)
      ..lineTo(46.8, 95.15)
      ..quadraticBezierTo(44.4, 88.5, 39.4, 88.5)
      ..quadraticBezierTo(35.3, 88.5, 32.9, 95.15)
      ..close();

    final hullBounds = hull.getBounds();
    canvas.drawPath(
      hull,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-0.95, -0.9),
          end: const Alignment(0.85, 1),
          colors: const [
            Color(0xFFFEF08A),
            Color(0xFFFACC15),
            Color(0xFFCA8A04),
            Color(0xFF92400E),
          ],
          stops: const [0, 0.35, 0.68, 1],
        ).createShader(hullBounds.inflate(2)),
    );

    // Rocker / lower body shade (metal reads darker near road)
    final rocker = Path()
      ..moveTo(33.5, 88.8)
      ..lineTo(74.5, 88.8)
      ..lineTo(74.5, 95.15)
      ..lineTo(33.5, 95.15)
      ..close();
    canvas.drawPath(
      rocker,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFEAB308).withValues(alpha: 0),
            const Color(0xFF92400E).withValues(alpha: 0.22),
          ],
        ).createShader(rocker.getBounds()),
    );

    canvas.drawPath(
      hull,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFF92400E).withValues(alpha: 0.45),
    );

    // Waist chrome line (follows long wedge shoulder)
    canvas.drawLine(
      const Offset(34.2, 85.2),
      const Offset(73.8, 85.2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 0.45,
    );

    // Greenhouse glass (steep windshield + side glass, matches demo B)
    final glass = Path()
      ..moveTo(42.0, 71.2)
      ..lineTo(48.0, 57.8)
      ..lineTo(69.5, 56.8)
      ..lineTo(73.2, 66.8)
      ..close();
    final gRect = glass.getBounds();
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFFE0F2F1),
            Color(0xFF0F766E),
            Color(0xFF042F2E),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(gRect.inflate(1)),
    );
    canvas.drawPath(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.55
        ..color = Colors.white.withValues(alpha: 0.5),
    );

    // B-pillar
    canvas.drawLine(
      const Offset(56.8, 58.5),
      const Offset(56.8, 71.0),
      Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.35)
        ..strokeWidth = 0.7,
    );

    // Roof taxi board (demo B proportions: slightly rear of center)
    final lampOuter = RRect.fromRectAndRadius(
      const Rect.fromLTWH(51.2, 51.2, 15.0, 4.9),
      const Radius.circular(0.85),
    );
    canvas.drawRRect(lampOuter, Paint()..color = const Color(0xFF171717));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(51.85, 52.0, 13.7, 3.4),
        const Radius.circular(0.45),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
        ).createShader(const Rect.fromLTWH(51.85, 52.0, 13.7, 3.4)),
    );

    // Side mirror stub (forward on long hood)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(31.2, 69.5, 2.5, 1.85),
        const Radius.circular(0.4),
      ),
      Paint()..color = const Color(0xFF1E293B),
    );

    // Headlamp cluster (low nose — tucked forward)
    final head = RRect.fromRectAndRadius(
      const Rect.fromLTWH(30.5, 73.0, 4.5, 2.75),
      const Radius.circular(1.1),
    );
    canvas.drawRRect(
      head,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFEF9C3)],
        ).createShader(head.outerRect),
    );
    canvas.drawRRect(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.35
        ..color = const Color(0xFFCA8A04).withValues(alpha: 0.5),
    );

    // Rear combination lamp (vertical slice on tall deck)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(73.85, 74.5, 2.25, 7.0),
        const Radius.circular(0.6),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
        ).createShader(const Rect.fromLTWH(73.85, 74.5, 2.25, 7.0)),
    );

    _cabWheel(canvas, const Offset(40.5, 94.05));
    _cabWheel(canvas, const Offset(62.8, 94.05));
  }

  /// Tire + alloy — smaller vs body so it reads like a car, not chunky toy wheels.
  void _cabWheel(Canvas canvas, Offset c) {
    const r = 4.35;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0A0F18));
    canvas.drawCircle(c, r * 0.9, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(c, r * 0.64, Paint()..color = const Color(0xFF94A3B8));
    canvas.drawCircle(c, r * 0.52, Paint()..color = const Color(0xFFCBD5E1));
    canvas.drawCircle(c, r * 0.24, Paint()..color = const Color(0xFF475569));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.66),
      -2.35,
      1.05,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.55,
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
