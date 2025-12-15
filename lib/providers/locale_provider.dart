import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';

class LocaleProvider extends ChangeNotifier {
  static const Locale defaultLocale = Locale('sl');
  static const Set<String> supportedLanguageCodes = {'sl', 'en'};

  Locale _locale = defaultLocale;
  bool _initialized = false;

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    final previous = _locale.languageCode;
    String? stored;
    try {
      final prefs = await SharedPreferences.getInstance();
      stored = prefs.getString(PreferenceKeys.selectedLanguage);
    } catch (_) {
      stored = null;
    }

    _locale = _fromCode(stored);
    _initialized = true;

    if (previous != _locale.languageCode) {
      notifyListeners();
    }
  }

  Future<void> setLanguageCode(String languageCode) async {
    final next = _fromCode(languageCode);
    if (_locale.languageCode == next.languageCode) return;

    _locale = next;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PreferenceKeys.selectedLanguage, _locale.languageCode);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocaleProvider: failed to persist locale: $e');
      }
    }
  }

  Locale _fromCode(String? raw) {
    final code = (raw ?? '').toString().trim().toLowerCase();
    if (supportedLanguageCodes.contains(code)) {
      return Locale(code);
    }
    return defaultLocale;
  }
}
