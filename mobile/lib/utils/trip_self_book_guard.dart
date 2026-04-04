import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';

/// Warning when the logged-in user tries to book seats on their own posted ride.
Future<void> showCannotBookOwnTripDialog(BuildContext context) {
  final loc = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(loc.t('trip.self_book.title')),
      content: Text(loc.t('trip.self_book.body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(loc.t('app.ok')),
        ),
      ],
    ),
  );
}
