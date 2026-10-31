import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closure copy does not promise complete removal in either language', () {
    final english = AppLocalizationsEn();
    final slovenian = AppLocalizationsSl();
    expect(english.settingsDeleteAccountDialogBody, contains('further review'));
    expect(english.settingsAccountDeletedToast,
        contains('may require further review'));
    expect(english.settingsAccountDeletedToast,
        isNot(contains('All data has been removed')));
    expect(
        slovenian.settingsDeleteAccountDialogBody, contains('dodaten pregled'));
    expect(slovenian.settingsAccountDeletedToast, contains('dodaten pregled'));
    expect(slovenian.settingsAccountDeletedToast,
        isNot(contains('Vsi podatki so odstranjeni')));
  });
}
