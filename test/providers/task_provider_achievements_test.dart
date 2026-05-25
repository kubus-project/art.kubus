import 'dart:convert';

import 'package:art_kubus/models/achievements.dart' as achievements;
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('applyAchievementResult updates first_post progress and KUB8 total', () {
    final provider = TaskProvider()..initializeProgress();

    provider.applyAchievementResult(
      achievements.AchievementEventResult(
        progress: [
          achievements.AchievementProgress(
            achievementCode: 'first_post',
            currentProgress: 1,
            requiredCount: 1,
            isCompleted: true,
            completedAt: DateTime.utc(2026, 5, 25),
          ),
        ],
        unlocked: [
          achievements.UserAchievement(
            code: 'first_post',
            title: 'First Post',
            description: 'Created your first community post',
            category: 'community',
            rarity: 'common',
            kub8Reward: 5,
            rewardCurrency: 'KUB8',
            unlockedAt: DateTime.utc(2026, 5, 25),
          ),
        ],
        totalKub8Earned: 5,
      ),
    );

    final progress = provider.getAchievementProgress('first_post');
    expect(progress, isNotNull);
    expect(progress!.isCompleted, isTrue);
    expect(progress.currentProgress, 1);
    expect(provider.totalKub8Earned, 5);
  });

  test('refreshAchievementsForCurrentUser reloads backend progress and KUB8',
      () async {
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

    final provider = TaskProvider();
    await provider.refreshAchievementsForCurrentUser();

    expect(provider.backendDefinitionFor('first_post')?.kub8Reward, 5);
    expect(provider.getAchievementProgress('first_post')?.isCompleted, isTrue);
    expect(provider.totalKub8Earned, 5);
  });
}
