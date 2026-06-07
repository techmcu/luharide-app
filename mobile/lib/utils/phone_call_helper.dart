import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/localization/app_localizations.dart';

Future<void> launchPhoneCall(BuildContext context, String phone) async {
  final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return;

  final uri = Uri(scheme: 'tel', path: digits);
  final loc = AppLocalizations.of(context);

  if (kIsWeb) {
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.t('app.phone_label')}: $digits'),
          action: SnackBarAction(
            label: loc.t('app.copy_number'),
            onPressed: () => Clipboard.setData(ClipboardData(text: digits)),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
    return;
  }

  try {
    final launched = await launchUrl(uri);
    if (!launched) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.t('app.dialer_failed')}: $digits'),
          action: SnackBarAction(
            label: loc.t('app.copy'),
            onPressed: () => Clipboard.setData(ClipboardData(text: digits)),
          ),
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${loc.t('app.phone_label')}: $digits'),
        action: SnackBarAction(
          label: loc.t('app.copy'),
          onPressed: () => Clipboard.setData(ClipboardData(text: digits)),
        ),
      ),
    );
  }
}
