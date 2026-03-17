import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported app languages.
enum AppLanguageCode { en, hi }

class AppLanguageProvider with ChangeNotifier {
  static const _prefsKey = 'app_language';

  AppLanguageCode _language = AppLanguageCode.en; // default English
  bool _initialized = false;

  AppLanguageCode get language => _language;
  Locale get locale => _language == AppLanguageCode.hi ? const Locale('hi') : const Locale('en');
  bool get isInitialized => _initialized;

  AppLanguageProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == 'hi') {
      _language = AppLanguageCode.hi;
    } else {
      _language = AppLanguageCode.en;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguageCode code) async {
    if (_language == code) return;
    _language = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code == AppLanguageCode.hi ? 'hi' : 'en');
  }
}

