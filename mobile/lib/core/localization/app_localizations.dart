import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/app_language_provider.dart';

/// Very lightweight key-based localization for English & Hindi.
class AppLocalizations {
  final AppLanguageCode code;

  AppLocalizations(this.code);

  static AppLocalizations of(BuildContext context) {
    // Use listen: false so we can safely call from event handlers (onTap, etc.).
    // MaterialApp already rebuilds on language change via AppLanguageProvider.
    final lang = Provider.of<AppLanguageProvider>(context, listen: false).language;
    return AppLocalizations(lang);
  }

  String get _lang => code == AppLanguageCode.hi ? 'hi' : 'en';

  static const Map<String, Map<String, String>> _values = {
    'app.profile.title': {
      'en': 'Profile',
      'hi': 'प्रोफ़ाइल',
    },
    'app.menu.language': {
      'en': 'Language',
      'hi': 'भाषा',
    },
    'app.menu.language.subtitle': {
      'en': 'Choose app language',
      'hi': 'ऐप की भाषा चुनें',
    },
    'app.language.english': {
      'en': 'English',
      'hi': 'अंग्रेज़ी',
    },
    'app.language.hindi': {
      'en': 'Hindi',
      'hi': 'हिन्दी',
    },
    'app.language.saved': {
      'en': 'Language updated',
      'hi': 'भाषा अपडेट हो गई',
    },
    'profile.section.union': {
      'en': 'For taxi union (admins)',
      'hi': 'टैक्सी यूनियन (एडमिन) के लिए',
    },
    'profile.section.driver': {
      'en': 'For independent taxi driver',
      'hi': 'स्वतंत्र टैक्सी ड्राइवर के लिए',
    },
  };

  String t(String key) {
    final byKey = _values[key];
    if (byKey == null) return key;
    return byKey[_lang] ?? byKey['en'] ?? key;
  }
}

