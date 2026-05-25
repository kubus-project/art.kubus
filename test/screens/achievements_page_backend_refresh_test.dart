import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/screens/web3/achievements/achievements_page.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  testWidgets('AchievementsPage refresh displays backend progress and KUB8',
      (tester) async {
    BackendApiService().setAuthTokenForTesting('token');
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/achievements/me')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'definitions': [
                {
                  'code': 'first_post',
                  'title': 'First Post',
                  'description': 'Created your first community post',
                  'category': 'community',
                  'rarity': 'common',
                  'requiredCount': 1,
                  'kub8Reward': 5,
                }
              ],
              'progress': [
                {
                  'achievementCode': 'first_post',
                  'currentProgress': 1,
                  'requiredCount': 1,
                  'isCompleted': true,
                }
              ],
              'unlocked': [
                {
                  'code': 'first_post',
                  'title': 'First Post',
                  'description': 'Created your first community post',
                  'category': 'community',
                  'rarity': 'common',
                  'kub8Reward': 5,
                  'rewardCurrency': 'KUB8',
                }
              ],
              'totalKub8Earned': 5,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TaskProvider(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AchievementsPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First Post'), findsOneWidget);
    expect(find.text('+5 KUB8'), findsOneWidget);
  });
}
