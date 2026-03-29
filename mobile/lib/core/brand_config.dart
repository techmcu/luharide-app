/// Product vs parent company — LuhaRide is the app; parent company is always **TECHMCU** (all caps in UI).
class BrandConfig {
  BrandConfig._();

  static const String appName = 'LuhaRide';

  /// Parent / company name — must stay **TECHMCU** (all caps). Do not use TechMCU / techmcu in user-facing strings.
  static const String parentBrand = 'TECHMCU';

  /// WhatsApp chat (India) — digits only for wa.me
  static const String whatsAppWaMeDigits = '917060618851';
  static const String whatsAppDisplay = '+91 70606 18851';

  static const String supportEmail = 'supportluharide@gmail.com';

  /// Public privacy policy page for Play Console. Empty until hosted — then set `https://...`.
  static const String privacyPolicyUrl = '';

  static Uri? get privacyPolicyUri {
    final s = privacyPolicyUrl.trim();
    if (s.isEmpty) return null;
    return Uri.tryParse(s);
  }

  static Uri get whatsAppUri => Uri.parse('https://wa.me/$whatsAppWaMeDigits');
}
