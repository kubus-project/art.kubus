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

  /// Resolve the launch locale from an entry [uri] under the direct-app-entry
  /// architecture, or `null` when the URL carries no supported locale (so the
  /// persisted/default locale applies). Precedence, highest first:
  ///
  ///   1. a locale-prefixed path — the bare app entries `/en`, `/sl` and the
  ///      canonical localized public-entity paths `/en/artworks/:id`,
  ///      `/sl/umetnine/:id` (the first path segment decides);
  ///   2. a supported `?lang=` / `?locale=` query parameter.
  ///
  /// The check is case-insensitive on the value but only ever returns a
  /// canonical lowercase supported code, so `/EN` or `?lang=SL` cannot leak an
  /// unsupported locale through.
  static String? localeCodeFromUri(Uri? uri) {
    if (uri == null) return null;

    for (final segment in uri.pathSegments) {
      final code = segment.trim().toLowerCase();
      if (code.isEmpty) continue;
      // Only the first non-empty segment can be a locale prefix. If it is not a
      // supported locale the path is not locale-prefixed, so fall through to the
      // query parameter rather than scanning deeper segments.
      return supportedLanguageCodes.contains(code)
          ? code
          : _localeFromQuery(uri);
    }

    return _localeFromQuery(uri);
  }

  static String? _localeFromQuery(Uri uri) {
    final query =
        (uri.queryParameters['lang'] ?? uri.queryParameters['locale'] ?? '')
            .trim()
            .toLowerCase();
    return supportedLanguageCodes.contains(query) ? query : null;
  }

  /// Initialize the active locale.
  ///
  /// [overrideLanguageCode] — typically resolved from the launch URL via
  /// [localeCodeFromUri] — takes precedence over the persisted locale so a
  /// direct `/en` or `/sl` entry renders in the right language on the first
  /// meaningful frame (no persisted-locale flash). A supported override is also
  /// persisted, so a later cold start without the locale in the URL keeps it.
  Future<void> initialize({String? overrideLanguageCode}) async {
    if (_initialized) return;

    final previous = _locale.languageCode;
    final override = _supportedOrNull(overrideLanguageCode);

    String? stored;
    if (override == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        stored = prefs.getString(PreferenceKeys.selectedLanguage);
      } catch (_) {
        stored = null;
      }
    }

    _locale = _fromCode(override ?? stored);
    _initialized = true;

    if (override != null) {
      await _persist(_locale.languageCode);
    }

    if (previous != _locale.languageCode) {
      notifyListeners();
    }
  }

  Future<void> setLanguageCode(String languageCode) async {
    final next = _fromCode(languageCode);
    if (_locale.languageCode == next.languageCode) return;

    _locale = next;
    notifyListeners();

    await _persist(_locale.languageCode);
  }

  Future<void> _persist(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PreferenceKeys.selectedLanguage, languageCode);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocaleProvider: failed to persist locale: $e');
      }
    }
  }

  static String? _supportedOrNull(String? raw) {
    final code = (raw ?? '').trim().toLowerCase();
    return supportedLanguageCodes.contains(code) ? code : null;
  }

  Locale _fromCode(String? raw) {
    final code = (raw ?? '').toString().trim().toLowerCase();
    if (supportedLanguageCodes.contains(code)) {
      return Locale(code);
    }
    return defaultLocale;
  }
}
