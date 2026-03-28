import 'package:flutter/material.dart';
import '../core/brand_config.dart';
import 'app_logo_mark.dart';

/// LuhaRide mark + title row — aligned for AppBar (start, `centerTitle: false`).
class BrandAppBarTitle extends StatelessWidget {
  const BrandAppBarTitle({
    super.key,
    required this.title,
    this.onColoredBar = false,
    this.logoSize = 34,
  });

  final Widget title;
  final bool onColoredBar;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final color = onColoredBar ? Colors.white : Colors.grey[800]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogoMark(size: logoSize, showPlate: !onColoredBar),
        SizedBox(width: onColoredBar ? 8 : 10),
        DefaultTextStyle(
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          child: title,
        ),
      ],
    );
  }
}

/// Passenger home: mark + app name.
class BrandAppBarTitleAppName extends StatelessWidget {
  const BrandAppBarTitleAppName({super.key, this.logoSize = 36});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return BrandAppBarTitle(
      logoSize: logoSize,
      title: const Text(BrandConfig.appName),
    );
  }
}
