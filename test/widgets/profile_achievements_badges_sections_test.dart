import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/achievement_progress.dart';
import 'package:art_kubus/models/achievements.dart' as backend;
import 'package:art_kubus/providers/attestation_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/widgets/attestation_badge_panel.dart';
import 'package:art_kubus/widgets/profile/profile_achievements_preview_section.dart';
import 'package:art_kubus/widgets/profile/profile_badges_verification_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _localizedHarness(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AttestationProvider()),
      ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ChangeNotifierProvider(create: (_) => TaskProvider()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('profile sections show badges separately from achievements',
      (tester) async {
    await tester.pumpWidget(
      _localizedHarness(
        const Column(
          children: [
            ProfileBadgesVerificationSection(),
            ProfileAchievementsPreviewSection(
              mode: ProfileAchievementsPreviewMode.ownProfile,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Badges & verification'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Achievements'),
        matching: find.byType(AttestationBadgePanel),
      ),
      findsNothing,
    );
  });

  testWidgets('wallet attestation copy is not achievement copy',
      (tester) async {
    await tester.pumpWidget(
      _localizedHarness(
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return AttestationBadgePanel(
              title: l10n.walletBadgesVerificationTitle,
              subtitle: l10n.walletBadgesVerificationSubtitle,
            );
          },
        ),
      ),
    );

    expect(find.text('Wallet badges & verification'), findsOneWidget);
    expect(find.text('Achievements'), findsNothing);
  });

  testWidgets('public profile preview uses backend reward fixture data',
      (tester) async {
    await tester.pumpWidget(
      _localizedHarness(
        const ProfileAchievementsPreviewSection(
          mode: ProfileAchievementsPreviewMode.publicProfile,
          publicDefinitions: [
            backend.AchievementDefinition(
              code: 'backend_badge',
              title: 'Backend Milestone',
              description: 'Uses backend reward config',
              category: 'community',
              rarity: 'rare',
              requiredCount: 1,
              kub8Reward: 9,
            ),
          ],
          publicProgress: [
            AchievementProgress(
              achievementId: 'backend_badge',
              currentProgress: 1,
              isCompleted: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Backend Milestone'), findsOneWidget);
    expect(find.text('+9 KUB8'), findsOneWidget);
  });
}
