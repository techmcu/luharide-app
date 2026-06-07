import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/localization/app_localizations.dart';

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
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(loc.t('app.exit_confirm')),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: widget.child,
    );
  }
}
