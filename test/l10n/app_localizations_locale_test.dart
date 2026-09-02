import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated localizations retain the supported locale safety guard', () {
    expect(AppLocalizationsEn(' en ').localeName, 'en');
    expect(AppLocalizationsSl('sl').localeName, 'sl');
    expect(AppLocalizationsEn('de').localeName, 'sl');
  });
}
