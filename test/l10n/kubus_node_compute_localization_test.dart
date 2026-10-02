import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network compute privacy and reward rails are localized', () {
    final en = AppLocalizationsEn();
    final sl = AppLocalizationsSl();

    expect(en.spatialRemotePrivacyBody, contains('temporarily decrypts'));
    expect(sl.spatialRemotePrivacyBody, contains('začasno dešifrirajo'));
    expect(en.kubusNodeArchiveContribution,
        isNot(en.kubusNodeComputeContribution));
    expect(sl.kubusNodeArchiveContribution,
        isNot(sl.kubusNodeComputeContribution));
    expect(en.kubusNodeSettlementPending, contains('not yet active'));
    expect(sl.kubusNodeSettlementPending, contains('še ni aktivna'));
  });
}
