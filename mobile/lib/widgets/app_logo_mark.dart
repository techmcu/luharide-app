import 'dart:math' as math;
import 'package:flutter/material.dart';

/// LuhaRide launcher art from [assets/branding/luharide_launcher_master.png] (1024² master).
class AppLogoMark extends StatelessWidget {
  final double size;
  final bool showPlate;

  const AppLogoMark({
    super.key,
    this.size = 40,
    this.showPlate = true,
  });

  static const assetPath = 'assets/branding/luharide_launcher_master.png';

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      gaplessPlayback: true,
    );
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          showPlate ? size * (24 / 108) : size * 0.2,
        ),
        child: img,
      ),
    );
  }
}

/// Subtle scale pulse — login / splash only.
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
        return Transform.scale(
          scale: breathe,
          child: AppLogoMark(size: widget.size, showPlate: widget.showPlate),
        );
      },
    );
  }
}
