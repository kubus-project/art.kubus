import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/achievement_preview_data_state.dart';
import 'package:art_kubus/models/achievement_progress.dart';
import 'package:art_kubus/models/achievements.dart' as backend;
import 'package:art_kubus/providers/attestation_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/widgets/attestation_badge_panel.dart';
import 'package:art_kubus/widgets/profile/profile_achievements_preview_section.dart';
import 'package:art_kubus/widgets/profile/profile_badges_verification_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _localizedHarness(
  Widget child, {
  TaskProvider? taskProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AttestationProvider()),
      ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ChangeNotifierProvider(create: (_) => taskProvider ?? TaskProvider()),
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
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
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

    expect(find.text('Profile badges'), findsOneWidget);
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

    expect(find.text('Wallet badges'), findsOneWidget);
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

  testWidgets('public profile loading does not humanize achievement codes',
      (tester) async {
    await tester.pumpWidget(
      _localizedHarness(
        const ProfileAchievementsPreviewSection(
          mode: ProfileAchievementsPreviewMode.publicProfile,
          dataState: AchievementPreviewDataState.loading,
          publicProgress: [
            AchievementProgress(
              achievementId: 'first_post',
              currentProgress: 1,
              isCompleted: true,
            ),
          ],
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('profile-achievements-loading')),
      findsOneWidget,
    );
    expect(find.text('First Post'), findsNothing);
    expect(find.text('first_post'), findsNothing);
  });

  testWidgets('public progress-only fallback stays subdued and stable',
      (tester) async {
    await tester.pumpWidget(
      _localizedHarness(
        const ProfileAchievementsPreviewSection(
          mode: ProfileAchievementsPreviewMode.publicProfile,
          dataState: AchievementPreviewDataState.fallback,
          publicProgress: [
            AchievementProgress(
              achievementId: 'first_post',
              currentProgress: 1,
              isCompleted: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Milestone recorded'), findsOneWidget);
    expect(find.text('First Post'), findsNothing);
    expect(find.textContaining('KUB8'), findsNothing);
  });

  testWidgets('own profile waits for backend achievement definitions',
      (tester) async {
    BackendApiService().setAuthTokenForTesting('token');
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/achievements/me')) {
          return http.Response(
            '{"success":true,"definitions":[{"code":"backend_milestone","title":"Backend Milestone","description":"Loaded from backend","category":"community","rarity":"rare","requiredCount":1,"kub8Reward":7}],"progress":[{"achievementCode":"backend_milestone","currentProgress":1,"requiredCount":1,"isCompleted":true}],"unlocked":[],"totalKub8Earned":7}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    final taskProvider = TaskProvider();
    await tester.pumpWidget(
      _localizedHarness(
        const ProfileAchievementsPreviewSection(
          mode: ProfileAchievementsPreviewMode.ownProfile,
        ),
        taskProvider: taskProvider,
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('profile-achievements-loading')),
      findsOneWidget,
    );
    expect(find.text('First Post'), findsNothing);

    await taskProvider.refreshAchievementsForCurrentUser();
    await tester.pumpAndSettle();

    expect(find.text('Backend Milestone'), findsOneWidget);
    expect(find.text('+7 KUB8'), findsOneWidget);
  });
}
