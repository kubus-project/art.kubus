import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppLocalizations guards invalid locale tags', () {
    final l10nUndefined = AppLocalizationsEn('undefined');
    final l10nNull = AppLocalizationsSl('null');
    final l10nEmpty = AppLocalizationsEn('');

    expect(l10nUndefined.localeName, equals('sl'));
    expect(l10nNull.localeName, equals('sl'));
    expect(l10nEmpty.localeName, equals('sl'));
  });
}
