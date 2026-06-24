import 'package:flutter/material.dart';

/// App-wide transient feedback (Material [SnackBar]).
///
/// Single entry point keeps API/UI/network messages consistent: floating bar,
/// safe-area margin, semantic tint (success / warning / error / info). Screens
/// should pass **user-facing** strings only (e.g. from backend `message` or
/// [userFacingAuthError]); never raw exception objects.
enum AppFeedbackKind {
  success,
  warning,
  error,
  info,
}

abstract final class AppFeedback {
  static Color _alpha(Color c, double a) => c.withValues(alpha: a);

  static Color _background(BuildContext context, AppFeedbackKind kind) {
    final error = Theme.of(context).colorScheme.error;
    switch (kind) {
      case AppFeedbackKind.success:
        return _alpha(const Color(0xFF1B5E20), 0.92);
      case AppFeedbackKind.warning:
        return _alpha(const Color(0xFFE65100), 0.92);
      case AppFeedbackKind.error:
        return _alpha(error, 0.92);
      case AppFeedbackKind.info:
        return _alpha(const Color(0xFF263238), 0.90);
    }
  }

  static Duration _duration(AppFeedbackKind kind, {bool hasAction = false}) {
    // Industry-standard snackbar timings (Android Toast: short ~2s, long ~3.5s).
    switch (kind) {
      case AppFeedbackKind.success:
        return const Duration(seconds: 2);
      case AppFeedbackKind.warning:
        return const Duration(seconds: 3);
      case AppFeedbackKind.error:
        return Duration(milliseconds: hasAction ? 4000 : 3500);
      case AppFeedbackKind.info:
        return const Duration(seconds: 2);
    }
  }

  static EdgeInsets _margin(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottom = mq.padding.bottom + mq.viewPadding.bottom;
    return EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom);
  }

  /// Non-dismissible loading hint; call [ScaffoldFeatureController.close] when done.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoading(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 30),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: _margin(context),
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: _background(context, AppFeedbackKind.info),
        duration: duration,
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void show(
    BuildContext context,
    String message, {
    AppFeedbackKind kind = AppFeedbackKind.info,
    Duration? duration,
    SnackBarAction? action,
    IconData? icon,
  }) {
    if (!context.mounted) return;
    showFromMessenger(
      ScaffoldMessenger.of(context),
      message,
      kind: kind,
      duration: duration,
      action: action,
      icon: icon,
    );
  }

  /// After [Navigator.pop] the dialog [BuildContext] is unmounted — capture
  /// [ScaffoldMessenger.of] before pop and call this to show feedback on the
  /// underlying screen.
  static void showFromMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    AppFeedbackKind kind = AppFeedbackKind.info,
    Duration? duration,
    SnackBarAction? action,
    IconData? icon,
  }) {
    final context = messenger.context;
    if (!context.mounted) return;
    final text = message.trim().isEmpty ? 'Something went wrong.' : message.trim();
    messenger.hideCurrentSnackBar();
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.35,
    );
    final Widget body = icon == null
        ? Text(
            text,
            style: textStyle,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: textStyle,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: _margin(context),
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: _background(context, kind),
        duration: duration ?? _duration(kind, hasAction: action != null),
        action: action,
        content: body,
      ),
    );
  }
}
