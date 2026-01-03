import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profileYearsActiveValue never renders placeholder #', () {
    final en = AppLocalizationsEn();
    final sl = AppLocalizationsSl();

    expect(en.profileYearsActiveValue(1).contains('#'), isFalse);
    expect(en.profileYearsActiveValue(2).contains('#'), isFalse);
    expect(sl.profileYearsActiveValue(1).contains('#'), isFalse);
    expect(sl.profileYearsActiveValue(2).contains('#'), isFalse);
  });
}

