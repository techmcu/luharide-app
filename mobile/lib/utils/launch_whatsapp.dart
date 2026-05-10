import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp chat with the given phone number.
/// Number can include spaces/dashes; only digits and leading + are used.
/// Does not display the number to the user (privacy).
Future<bool> launchWhatsApp(String? phoneOrWhatsapp) async {
  if (phoneOrWhatsapp == null || phoneOrWhatsapp.trim().isEmpty) return false;
  String digits = phoneOrWhatsapp.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
  if (digits.startsWith('+')) {
    digits = digits.substring(1).replaceAll(RegExp(r'\D'), '');
  } else {
    digits = digits.replaceAll(RegExp(r'\D'), '');
  }
  if (digits.isEmpty) return false;
  if (!digits.startsWith('91') && digits.length <= 10) {
    digits = '91$digits'; // India default
  }
  try {
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
  return false;
}
