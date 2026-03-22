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
    'union.register.title': {
      'en': 'Add your union',
      'hi': 'अपनी यूनियन जोड़ें',
    },
    'union.warning.title': {
      'en': 'Important',
      'hi': 'महत्वपूर्ण',
    },
    'union.warning.body': {
      'en':
          'This form is only for an authorised taxi union representative. False or misleading information may lead to your account being restricted. Submit only if you are eligible.',
      'hi':
          'यह फॉर्म केवल अधिकृत टैक्सी यूनियन प्रतिनिधि के लिए है। गलत या भ्रामक जानकारी पर आपके खाते पर प्रतिबंध लग सकता है। केवल तभी भरें जब आप योग्य हों।',
    },
    'exclusivity.union_blocked.title': {
      'en': 'Not available',
      'hi': 'उपलब्ध नहीं',
    },
    'exclusivity.union_blocked.body': {
      'en':
          'You already use the independent driver path (pending or approved). Union registration is not available on this account.',
      'hi':
          'आप पहले से स्वतंत्र ड्राइवर मार्ग का उपयोग कर रहे हैं (लंबित या स्वीकृत)। इस खाते पर यूनियन पंजीकरण उपलब्ध नहीं है।',
    },
    'exclusivity.driver_blocked.title': {
      'en': 'Not available',
      'hi': 'उपलब्ध नहीं',
    },
    'exclusivity.driver_blocked.body': {
      'en':
          'You already use the union path (pending or approved). Independent driver verification is not available on this account.',
      'hi':
          'आप पहले से यूनियन मार्ग का उपयोग कर रहे हैं (लंबित या स्वीकृत)। इस खाते पर स्वतंत्र ड्राइवर सत्यापन उपलब्ध नहीं है।',
    },
    'profile.logout': {
      'en': 'Sign out',
      'hi': 'साइन आउट',
    },
    'profile.logout.subtitle': {
      'en': 'Log out of your account',
      'hi': 'अपने खाते से बाहर निकलें',
    },
    'app.ok': {
      'en': 'OK',
      'hi': 'ठीक',
    },
  };

  String t(String key) {
    final byKey = _values[key];
    if (byKey == null) return key;
    return byKey[_lang] ?? byKey['en'] ?? key;
  }
}

