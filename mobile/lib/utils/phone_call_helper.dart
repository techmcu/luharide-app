import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launch a phone call — works on native Android/iOS and web.
///
/// On Android 11+, canLaunchUrl for tel: can falsely return false even when
/// dialer exists (package visibility). We skip canLaunchUrl and launch directly.
/// If launch fails, shows a snackbar with the number + copy option.
Future<void> launchPhoneCall(BuildContext context, String phone) async {
  final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return;

  final uri = Uri(scheme: 'tel', path: digits);

  if (kIsWeb) {
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone: $digits'),
          action: SnackBarAction(
            label: 'Copy Number',
            onPressed: () => Clipboard.setData(ClipboardData(text: digits)),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
    return;
  }

  // Native: launch directly without canLaunchUrl check (Android 11+ unreliable)
  try {
    final launched = await launchUrl(uri);
    if (!launched) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open dialer: $digits'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () => Clipboard.setData(ClipboardData(text: digits)),
          ),
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phone: $digits'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () => Clipboard.setData(ClipboardData(text: digits)),
        ),
      ),
    );
  }
}
