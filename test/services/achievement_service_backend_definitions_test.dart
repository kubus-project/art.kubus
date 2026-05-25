import 'dart:convert';

import 'package:art_kubus/services/achievement_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('getAllAchievements returns backend definitions when available',
      () async {
    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/achievements')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'achievements': [
                {
                  'code': 'first_post',
                  'title': 'Backend First Post',
                  'description': 'Backend-owned definition',
                  'category': 'community',
                  'rarity': 'common',
                  'kub8Reward': 9,
                  'rule': {
                    'eventType': 'post_created',
                    'metricKey': 'post_count',
                    'requiredCount': 1,
                  },
                }
              ],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );

    final definitions = await AchievementService().getAllAchievements();

    expect(definitions, hasLength(1));
    expect(definitions.single.title, 'Backend First Post');
    expect(definitions.single.kub8Reward, 9);
    expect(definitions.single.eventType, 'post_created');
  });

  test('getAllAchievements uses static definitions only as fallback',
      () async {
    BackendApiService().setHttpClient(
      MockClient((request) async => http.Response('{}', 503)),
    );

    final definitions = await AchievementService().getAllAchievements();

    expect(definitions, isNotEmpty);
    expect(definitions.any((definition) => definition.code == 'first_post'),
        isTrue);
    expect(
      definitions.firstWhere((definition) => definition.code == 'first_post')
          .kub8Reward,
      5,
    );
  });
}
