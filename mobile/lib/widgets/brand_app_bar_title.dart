import 'package:flutter/material.dart';
import '../core/brand_config.dart';

/// App bar title text only (launcher icon is separate; no in-app logo image).
class BrandAppBarTitle extends StatelessWidget {
  const BrandAppBarTitle({
    super.key,
    required this.title,
    this.onColoredBar = false,
  });

  final Widget title;
  final bool onColoredBar;

  @override
  Widget build(BuildContext context) {
    final color = onColoredBar ? Colors.white : Colors.grey[800]!;
    return DefaultTextStyle(
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      child: title,
    );
  }
}

/// Passenger home: app name only.
class BrandAppBarTitleAppName extends StatelessWidget {
  const BrandAppBarTitleAppName({super.key});

  @override
  Widget build(BuildContext context) {
    return const BrandAppBarTitle(
      title: Text(BrandConfig.appName),
    );
  }
}
