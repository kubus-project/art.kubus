import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/providers/locale_provider.dart';

void main() {
  group('LocaleProvider.localeCodeFromUri', () {
    String? resolve(String url) =>
        LocaleProvider.localeCodeFromUri(Uri.parse(url));

    test('bare locale roots select the locale', () {
      expect(resolve('https://app.kubus.site/en'), 'en');
      expect(resolve('https://app.kubus.site/sl'), 'sl');
      expect(resolve('https://app.kubus.site/en/'), 'en');
      expect(resolve('https://app.kubus.site/sl/'), 'sl');
    });

    test('localized public-entity paths keep their locale', () {
      expect(resolve('https://app.kubus.site/en/artworks/abc'), 'en');
      expect(resolve('https://app.kubus.site/sl/umetnine/abc'), 'sl');
    });

    test('root without a locale falls back to null', () {
      expect(resolve('https://app.kubus.site/'), isNull);
    });

    test('query lang / locale are honoured when the path has no locale', () {
      expect(resolve('https://app.kubus.site/?lang=en'), 'en');
      expect(resolve('https://app.kubus.site/?lang=sl'), 'sl');
      expect(resolve('https://app.kubus.site/?locale=en'), 'en');
      expect(resolve('https://app.kubus.site/?locale=sl'), 'sl');
    });

    test('query lang is honoured in every position and preserves siblings', () {
      // only
      expect(resolve('https://app.kubus.site/?lang=sl'), 'sl');
      // first
      expect(resolve('https://app.kubus.site/?lang=sl&utm_source=x'), 'sl');
      // last
      expect(resolve('https://app.kubus.site/?utm_source=x&lang=sl'), 'sl');
      // middle
      expect(resolve('https://app.kubus.site/?a=1&lang=sl&b=2'), 'sl');
    });

    test('a locale-prefixed path wins over a conflicting query parameter', () {
      expect(resolve('https://app.kubus.site/en/artworks/abc?lang=sl'), 'en');
      expect(resolve('https://app.kubus.site/sl?lang=en'), 'sl');
    });

    test('a non-locale first segment falls through to the query', () {
      expect(resolve('https://app.kubus.site/app?lang=sl'), 'sl');
      expect(resolve('https://app.kubus.site/main'), isNull);
    });

    test('unsupported locales never leak through', () {
      expect(resolve('https://app.kubus.site/fr'), isNull);
      expect(resolve('https://app.kubus.site/?lang=de'), isNull);
      // case-insensitive value, canonical lowercase result
      expect(resolve('https://app.kubus.site/?lang=SL'), 'sl');
      expect(resolve('https://app.kubus.site/EN'), 'en');
    });

    test('null uri resolves to null', () {
      expect(LocaleProvider.localeCodeFromUri(null), isNull);
    });
  });

  group('LocaleProvider.initialize', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('a supported override wins over the persisted locale and is persisted',
        () async {
      SharedPreferences.setMockInitialValues(
        {PreferenceKeys.selectedLanguage: 'sl'},
      );
      final provider = LocaleProvider();
      await provider.initialize(overrideLanguageCode: 'en');
      expect(provider.languageCode, 'en');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PreferenceKeys.selectedLanguage), 'en');
    });

    test('no override falls back to the persisted locale', () async {
      SharedPreferences.setMockInitialValues(
        {PreferenceKeys.selectedLanguage: 'en'},
      );
      final provider = LocaleProvider();
      await provider.initialize();
      expect(provider.languageCode, 'en');
    });

    test('an unsupported override is ignored in favour of persisted/default',
        () async {
      SharedPreferences.setMockInitialValues(
        {PreferenceKeys.selectedLanguage: 'en'},
      );
      final provider = LocaleProvider();
      await provider.initialize(overrideLanguageCode: 'fr');
      expect(provider.languageCode, 'en');
    });
  });
}
