import 'dart:math' as math;
import 'package:flutter/material.dart';

/// LuhaRide mark: graphic black peaks + snow, golden mountain road, cab, location pin (refined travel identity).
/// No text. In-app gradients; launcher XML uses flat fills.
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
    _drawMountainsGraphic(canvas);
    _drawRoadGold(canvas);
    canvas.save();
    canvas.translate(9, -1.5);
    _drawCabShadow(canvas);
    _drawCab(canvas);
    canvas.restore();
    _drawPinGraphic(canvas);

    canvas.restore();
    canvas.restore();
  }

  void _drawSky(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, 108, 56);
    final g = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFF8FAFC),
        const Color(0xFFE2E8F0).withValues(alpha: 0.65),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0, 0.45, 1],
    );
    canvas.drawRect(rect, Paint()..shader = g.createShader(rect));
    // Subtle warm corner (nod to split-circle refinement) — very light
    final vignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, 0.35),
        radius: 1.05,
        colors: [
          const Color(0xFFFFE566).withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(const Rect.fromLTWH(0, 0, 108, 108));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 108, 108), vignette);
  }

  /// Sharp black mass + white caps — travel / mountain pass read (not a copy of any stock mark).
  void _drawMountainsGraphic(Canvas canvas) {
    final mass = Path()
      ..moveTo(0, 108)
      ..lineTo(0, 70)
      ..lineTo(14, 52)
      ..lineTo(26, 62)
      ..lineTo(44, 38)
      ..lineTo(58, 48)
      ..lineTo(76, 30)
      ..lineTo(90, 44)
      ..lineTo(102, 36)
      ..lineTo(108, 42)
      ..lineTo(108, 108)
      ..close();
    canvas.drawPath(mass, Paint()..color = const Color(0xFF0A0A0A));
    final mass2 = Path()
      ..moveTo(0, 108)
      ..lineTo(0, 78)
      ..lineTo(32, 58)
      ..lineTo(52, 68)
      ..lineTo(72, 52)
      ..lineTo(108, 62)
      ..lineTo(108, 108)
      ..close();
    canvas.drawPath(
      mass2,
      Paint()..color = const Color(0xFF171717).withValues(alpha: 0.92),
    );

    final cap1 = Path()
      ..moveTo(38, 44)
      ..lineTo(44, 34)
      ..lineTo(50, 46)
      ..close();
    final cap2 = Path()
      ..moveTo(70, 32)
      ..lineTo(76, 24)
      ..lineTo(82, 36)
      ..close();
    final cap3 = Path()
      ..moveTo(96, 34)
      ..lineTo(102, 28)
      ..lineTo(108, 38)
      ..close();
    const snow = Color(0xFFF8FAFC);
    canvas.drawPath(cap1, Paint()..color = snow);
    canvas.drawPath(cap2, Paint()..color = snow);
    canvas.drawPath(cap3, Paint()..color = snow);
    canvas.drawPath(
      cap1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.35
        ..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.drawPath(
      cap2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.35
        ..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.drawPath(
      cap3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.35
        ..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  /// Golden highway into the pass — high contrast like pro travel marks.
  void _drawRoadGold(Canvas canvas) {
    final road = Path()
      ..moveTo(11, 103)
      ..quadraticBezierTo(50, 74, 101, 53);
    final roadRect = const Rect.fromLTWH(0, 48, 108, 62);
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFF1C1917)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      road,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFFFFE066), Color(0xFFF5C518), Color(0xFFE6A800)],
          stops: [0, 0.5, 1],
        ).createShader(roadRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFFFFFAD1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
    final dash = Path()
      ..moveTo(22, 95)
      ..quadraticBezierTo(52, 72, 90, 56);
    canvas.drawPath(
      dash,
      Paint()
        ..color = const Color(0xFFCA8A04).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
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
            Color(0xFFBFDBFE),
            Color(0xFF1E3A5F),
            Color(0xFF0F172A),
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

  /// Left pin + **black** centre hole (open-composition travel mark style).
  void _drawPinGraphic(Canvas canvas) {
    const cx = 22.0;
    const top = 14.5;
    final pinPath = Path()
      ..moveTo(cx, top)
      ..cubicTo(14.5, top, 8.5, 20.7, 8.5, 28.0)
      ..cubicTo(8.5, 36.0, cx, 47.5, cx, 47.5)
      ..cubicTo(cx, 47.5, 35.5, 36.0, 35.5, 28.0)
      ..cubicTo(35.5, 20.7, 29.5, top, cx, top)
      ..close();
    final pinRect = pinPath.getBounds();
    canvas.drawPath(
      pinPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.15, -0.55),
          radius: 1.05,
          colors: const [
            Color(0xFFFFE566),
            Color(0xFFFFD60A),
            Color(0xFFF5C518),
            Color(0xFFD97706),
          ],
          stops: const [0, 0.32, 0.68, 1],
        ).createShader(pinRect.inflate(2)),
    );
    canvas.drawPath(
      pinPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFF1C1917).withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      const Offset(cx, 26.5),
      3.65,
      Paint()..color = const Color(0xFF0A0A0A),
    );
  }

  @override
  bool shouldRepaint(covariant _LuhaRideMarkPainter oldDelegate) =>
      oldDelegate.showPlate != showPlate || oldDelegate.breathe != breathe;
}
