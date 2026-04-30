import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExitGuard extends StatefulWidget {
  const ExitGuard({super.key, required this.child, this.onBackIntercept});

  final Widget child;

  /// Called on back press. Return true if back was consumed (e.g. cleared search).
  /// If null or returns false, the double-tap-to-exit logic runs.
  final bool Function()? onBackIntercept;

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (widget.onBackIntercept != null && widget.onBackIntercept!()) {
          return;
        }

        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: widget.child,
    );
  }
}
