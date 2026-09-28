import 'package:art_kubus/models/stats/stats_models.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/stats_provider.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_artist_studio_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_institution_hub_screen.dart';
import 'package:art_kubus/services/stats_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';
import '../../support/profile_fixtures.dart';

/// Returns every counter the backend knows, including the achievement
/// reward sum, whether or not the screen asked for it. The dashboards must
/// never present `achievementTokensTotal` as revenue or sales.
class _FakeStatsApi extends StatsApiService {
  int calls = 0;

  @override
  Future<StatsSnapshot> fetchSnapshot({
    required String entityType,
    required String entityId,
    List<String> metrics = const [],
    String scope = 'public',
    String? groupBy,
    bool forceRefresh = false,
  }) async {
    calls++;
    return StatsSnapshot(
      entityType: entityType,
      entityId: entityId,
      scope: scope,
      metrics: metrics,
      counters: const <String, int>{
        'achievementTokensTotal': 1250,
        'eventsHosted': 3,
        'visitorsReceived': 42,
        'exhibitionArtworks': 7,
        'artworks': 5,
        'viewsReceived': 900,
        'likesReceived': 64,
      },
      generatedAt: DateTime.utc(2026, 9, 28),
    );
  }
}

UserProfile _owner({bool artist = false, bool institution = false}) {
  return UserProfile(
    id: ProfileFixtures.wallet,
    userId: ProfileFixtures.wallet,
    walletAddress: ProfileFixtures.wallet,
    username: 'galerija',
    displayName: 'Galerija Vžigalica',
    bio: '',
    avatar: '',
    isArtist: artist,
    isInstitution: institution,
    createdAt: ProfileFixtures.fetchedAt,
    updatedAt: ProfileFixtures.fetchedAt,
  );
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required Widget child,
  required String onboardingKey,
  required UserProfile owner,
  required _FakeStatsApi api,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    '${onboardingKey}_onboarding_completed': true,
  });
  await pumpProductSurface(
    tester,
    size: const Size(1440, 900),
    signedInProfile: owner,
    extraProviders: [
      ChangeNotifierProvider<StatsProvider>(
        create: (_) => StatsProvider(api: api),
      ),
    ],
    child: child,
  );
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  test('institution dashboard metrics carry no revenue source', () {
    expect(
        institutionDashboardMetrics, isNot(contains('achievementTokensTotal')));
    expect(institutionDashboardMetrics, [
      'eventsHosted',
      'visitorsReceived',
      'exhibitionArtworks',
    ]);
  });

  testWidgets(
      'Institution desktop panel: no "Revenue", no KUB8, achievement '
      'reward sum never shown; programme counters are labelled truthfully',
      (tester) async {
    final api = _FakeStatsApi();
    await _pumpDashboard(
      tester,
      child: const DesktopInstitutionHubScreen(),
      onboardingKey: 'Institution Hub',
      owner: _owner(institution: true),
      api: api,
    );

    expect(api.calls, greaterThan(0), reason: 'panel reads real counters');
    expect(find.textContaining('Revenue'), findsNothing);
    expect(find.textContaining('KUB8'), findsNothing);
    expect(find.text('1250'), findsNothing);
    expect(find.text('0 KUB8'), findsNothing);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Programme page views'), findsOneWidget);
    expect(find.text('Visitors'), findsNothing,
        reason: 'page views are not physical visitors');
    expect(find.text('PROGRAMME'), findsWidgets);
  });

  testWidgets(
      'Artist Studio desktop panel: no "Sales" KUB8 tile, no placeholder '
      'activity; practice leads, promotion sits under infrastructure',
      (tester) async {
    final api = _FakeStatsApi();
    await _pumpDashboard(
      tester,
      child: const DesktopArtistStudioScreen(),
      onboardingKey: 'Artist Studio',
      owner: _owner(artist: true),
      api: api,
    );

    expect(find.textContaining('Sales'), findsNothing);
    expect(find.textContaining('KUB8'), findsNothing);
    expect(find.text('1250'), findsNothing);
    expect(find.text('No recent activity'), findsNothing);
    expect(find.text('900'), findsOneWidget);
    expect(find.text('64'), findsOneWidget);

    final practice = tester.getTopLeft(find.text('PRACTICE').first);
    final numbers = tester.getTopLeft(find.text('NUMBERS'));
    expect(practice.dy, lessThan(numbers.dy));
  });
}
