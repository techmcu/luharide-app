import 'package:flutter/material.dart';

/// Static PNG logo — [assets/branding/luharide_launcher_master.png].
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 40});

  final double size;

  static const assetPath = 'assets/branding/luharide_launcher_master.png';

  /// Login + signup: centered hero, same sizing on both screens.
  static double authHeroSize(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final short = MediaQuery.sizeOf(context).height < 600;
    if (short) return (w * 0.58).clamp(176.0, 228.0);
    return (w * 0.68).clamp(220.0, 300.0);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = (size * dpr).round().clamp(64, 1024);
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        cacheWidth: px,
        cacheHeight: px,
      ),
    );
  }
}
