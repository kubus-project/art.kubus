import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/achievement_service.dart' as achievement_svc;
import 'package:art_kubus/utils/achievement_ui.dart';
import 'package:art_kubus/utils/category_accent_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('maps icon/category/accent consistently for achievements',
      (tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final l10n = AppLocalizations.of(capturedContext)!;
    final discovery = achievement_svc
        .AchievementService.achievementDefinitions[
            achievement_svc.AchievementType.firstDiscovery]!;
    final event = achievement_svc.AchievementService.achievementDefinitions[
        achievement_svc.AchievementType.eventAttendee]!;

    expect(AchievementUi.iconFor(discovery), Icons.explore_outlined);
    expect(AchievementUi.iconFor(event), Icons.verified);

    final discoveryCategory = AchievementUi.categoryLabelFor(discovery, l10n);
    final eventCategory = AchievementUi.categoryLabelFor(event, l10n);

    expect(discoveryCategory, l10n.userProfileAchievementCategoryDiscovery);
    expect(eventCategory, l10n.userProfileAchievementCategoryEvents);

    final discoveryAccent = AchievementUi.accentFor(capturedContext, discovery);
    final expectedDiscoveryAccent =
        CategoryAccentColor.resolve(capturedContext, discoveryCategory);

    expect(discoveryAccent, expectedDiscoveryAccent);
  });
}
