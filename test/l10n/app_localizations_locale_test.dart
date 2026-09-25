import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated localizations retain the supported locale safety guard', () {
    expect(AppLocalizationsEn(' en ').localeName, 'en');
    expect(AppLocalizationsSl('sl').localeName, 'sl');
    expect(AppLocalizationsEn('de').localeName, 'sl');
  });

  test('artwork discovery notification copy is localized without reward claims',
      () {
    final en = AppLocalizationsEn('en');
    final sl = AppLocalizationsSl('sl');

    expect(en.notificationArtworkDiscoveredBody('River Memory', 'Ana'),
        contains('by Ana'));
    expect(en.notificationArtworkDiscoveredTitleOnlyBody('River Memory'),
        contains('River Memory'));
    expect(sl.notificationArtworkDiscoveredBody('Spomin reke', 'Ana'),
        contains('Ana'));
    expect(sl.notificationArtworkDiscoveredTitleOnlyBody('Spomin reke'),
        contains('Spomin reke'));
    expect(en.notificationArtworkDiscoveredBody('River Memory', 'Ana'),
        isNot(contains('KUB8')));
    expect(sl.notificationArtworkDiscoveredBody('Spomin reke', 'Ana'),
        isNot(contains('KUB8')));
  });
}
