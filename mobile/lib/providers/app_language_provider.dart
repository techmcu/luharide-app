import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/api_error_messages.dart';
import '../services/api_service.dart';

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
    setErrorMessageLocale(_language == AppLanguageCode.hi ? 'hi' : 'en');
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguageCode code) async {
    if (_language == code) return;
    _language = code;
    setErrorMessageLocale(code == AppLanguageCode.hi ? 'hi' : 'en');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final value = code == AppLanguageCode.hi ? 'hi' : 'en';
    await prefs.setString(_prefsKey, value);
    unawaited(_syncLanguageToBackend(value));
  }

  /// Tell the server the new language so notifications come in this language.
  /// Fire-and-forget: harmless 401 if not logged in yet (login re-syncs it).
  Future<void> _syncLanguageToBackend(String value) async {
    try {
      await ApiService().post('/notifications/language', data: {'language': value});
    } catch (_) {
      // ignored — login flow re-sends the language with the FCM token
    }
  }
}

