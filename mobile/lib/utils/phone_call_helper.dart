import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launch a phone call that works on both native and web (iOS Safari).
///
/// On native: uses canLaunchUrl check then launches tel: URL.
/// On web (iOS Safari / mobile browser): tel: URL triggers the phone dialer.
/// If tel: fails on web (desktop browser), shows a snackbar with copyable number.
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

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}
