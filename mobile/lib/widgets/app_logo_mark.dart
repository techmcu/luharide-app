import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Favicon-style mark: **cab + hills** only (no letters). Subtle breathe + gradient pulse + cab bob.
class AppLogoMark extends StatefulWidget {
  final double size;

  const AppLogoMark({super.key, this.size = 40});

  @override
  State<AppLogoMark> createState() => _AppLogoMarkState();
}

class _AppLogoMarkState extends State<AppLogoMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final phase = _ctrl.value;
        final breath = 1.0 + 0.04 * math.sin(phase * math.pi * 2);
        final r = widget.size * 0.22;
        return Transform.scale(
          scale: breath,
          alignment: Alignment.center,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withValues(
                    alpha: 0.28 + 0.08 * math.sin(phase * math.pi * 2),
                  ),
                  blurRadius: widget.size * 0.2,
                  offset: Offset(0, widget.size * 0.05),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(r),
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _CabHillFaviconPainter(t: phase),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Flat iconic silhouette: layered hills + taxi — favicon-readable, no typography.
class _CabHillFaviconPainter extends CustomPainter {
  _CabHillFaviconPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    final wave = (math.sin(t * math.pi * 2) * 0.5 + 0.5);
    final top = Color.lerp(
      const Color(0xFF0F766E),
      const Color(0xFF2DD4BF),
      0.22 + 0.12 * wave,
    )!;
    final bottom = Color.lerp(
      const Color(0xFF0D5C52),
      const Color(0xFF115E59),
      0.18 + 0.1 * (1 - wave),
    )!;

    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [top, bottom],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Distant hill
    final far = Path()
      ..moveTo(0, h * 0.58)
      ..lineTo(w * 0.22, h * 0.32)
      ..lineTo(w * 0.48, h * 0.44)
      ..lineTo(w * 0.72, h * 0.36)
      ..lineTo(w, h * 0.42)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      far,
      Paint()..color = const Color(0xFF5EEAD4).withValues(alpha: 0.45),
    );

    // Main peak (white)
    final peak = Path()
      ..moveTo(w * 0.06, h * 0.62)
      ..lineTo(w * 0.38, h * 0.2)
      ..lineTo(w * 0.62, h * 0.38)
      ..lineTo(w * 0.82, h * 0.28)
      ..lineTo(w * 0.94, h * 0.36)
      ..lineTo(w, h * 0.4)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(peak, Paint()..color = const Color(0xFFF8FAFC));

    // Foreground hill
    final near = Path()
      ..moveTo(0, h * 0.66)
      ..lineTo(w * 0.3, h * 0.52)
      ..lineTo(w * 0.55, h * 0.58)
      ..lineTo(w * 0.78, h * 0.48)
      ..lineTo(w, h * 0.54)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      near,
      Paint()..color = const Color(0xFFE2E8F0).withValues(alpha: 0.92),
    );

    // Cab with vertical bob
    final bob = math.sin(t * math.pi * 2) * h * 0.014;
    final cabW = w * 0.42;
    final cabH = h * 0.2;
    final cabX = (w - cabW) / 2;
    final cabY = h * 0.54 + bob;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(cabX, cabY + h * 0.035, cabW, cabH * 0.68),
      Radius.circular(h * 0.035),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFDE047));
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.016
        ..color = const Color(0xFFEAB308),
    );

    final roof = RRect.fromRectAndRadius(
      Rect.fromLTWH(cabX + cabW * 0.1, cabY, cabW * 0.8, h * 0.1),
      Radius.circular(h * 0.025),
    );
    canvas.drawRRect(roof, Paint()..color = const Color(0xFFFEF08A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cabX + cabW * 0.36, cabY + h * 0.022, cabW * 0.28, h * 0.034),
        Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFEF4444),
    );

    final glass = Paint()..color = const Color(0xFF0D9488);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cabX + cabW * 0.12, cabY + h * 0.055, cabW * 0.22, h * 0.06),
        Radius.circular(2),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cabX + cabW * 0.66, cabY + h * 0.055, cabW * 0.22, h * 0.06),
        Radius.circular(2),
      ),
      glass,
    );

    final wh = Paint()..color = const Color(0xFF1E293B);
    canvas.drawCircle(Offset(cabX + cabW * 0.24, cabY + cabH * 0.78), h * 0.038, wh);
    canvas.drawCircle(Offset(cabX + cabW * 0.76, cabY + cabH * 0.78), h * 0.038, wh);
  }

  @override
  bool shouldRepaint(covariant _CabHillFaviconPainter oldDelegate) =>
      oldDelegate.t != t;
}
