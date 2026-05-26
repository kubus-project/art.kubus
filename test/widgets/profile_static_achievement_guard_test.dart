import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'profile and wallet surfaces do not render static achievement definitions',
      () {
    const guardedFiles = [
      'lib/screens/community/profile_screen.dart',
      'lib/screens/community/user_profile_screen.dart',
      'lib/screens/desktop/community/desktop_profile_screen.dart',
      'lib/screens/desktop/community/desktop_user_profile_screen.dart',
      'lib/screens/web3/wallet/wallet_home.dart',
      'lib/screens/desktop/web3/desktop_wallet_screen.dart',
      'lib/widgets/profile/profile_achievements_preview_section.dart',
      'lib/widgets/profile/profile_badges_verification_section.dart',
    ];

    for (final path in guardedFiles) {
      final contents = File(path).readAsStringSync();
      expect(
        contents,
        isNot(contains('AchievementService.achievementDefinitions')),
        reason: '$path must not use static achievement definitions',
      );
      expect(
        contents,
        isNot(contains('desktopSettingsAchievementsTitle')),
        reason: '$path must not label badges/attestations as achievements',
      );
    }

    final previewContents = File(
      'lib/widgets/profile/profile_achievements_preview_section.dart',
    ).readAsStringSync();
    expect(
      previewContents,
      isNot(contains('_humanizeCode')),
      reason:
          'Profile achievement previews must not humanize codes during loading.',
    );
    expect(
      previewContents,
      isNot(contains("RegExp(r'[_-]+')")),
      reason:
          'Profile achievement previews must not derive display titles from codes.',
    );

    for (final path in const [
      'lib/screens/community/user_profile_screen.dart',
      'lib/screens/desktop/community/desktop_user_profile_screen.dart',
    ]) {
      final contents = File(path).readAsStringSync();
      expect(
        contents,
        isNot(contains('UserService.getUserById')),
        reason:
            '$path must route public profile loading through the shared controller/service.',
      );
      expect(
        contents,
        isNot(contains('AchievementPreviewDataState get')),
        reason: '$path must not implement achievement data-state logic.',
      );
    }

    for (final path in const [
      'lib/l10n/app_en.arb',
      'lib/l10n/app_sl.arb',
      'lib/l10n/app_localizations.dart',
      'lib/l10n/app_localizations_en.dart',
      'lib/l10n/app_localizations_sl.dart',
    ]) {
      final contents = File(path).readAsStringSync();
      expect(
        contents,
        isNot(contains('attestationBadgePanel')),
        reason: '$path must use the recognition badge copy namespace.',
      );
    }
  });
}
