import 'dart:convert';

import 'package:art_kubus/providers/recent_activity_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('in-app notifications default to unread when no read flags are present',
      () async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'in_app_notifications': <String>[
          jsonEncode(<String, dynamic>{
            'type': 'comment',
            'title': 'New comment',
            'body': 'Alice: Nice artwork!',
            'payload': <String, dynamic>{'postId': 'post-1'},
            'timestamp': '2026-04-04T10:00:00.000Z',
          }),
        ],
      },
    );

    final provider = RecentActivityProvider();

    await provider.refresh(force: true);

    expect(provider.activities, hasLength(1));
    expect(provider.unreadActivities, hasLength(1));
    expect(provider.activities.first.isRead, isFalse);
    expect(provider.activities.first.description, 'Alice: Nice artwork!');
  });

  test('explicit read flag still takes precedence for in-app notifications',
      () async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        'in_app_notifications': <String>[
          jsonEncode(<String, dynamic>{
            'type': 'reward',
            'title': 'Reward granted',
            'body': '+10 KUB8',
            'payload': <String, dynamic>{'amount': 10},
            'timestamp': '2026-04-04T11:00:00.000Z',
            'isRead': true,
          }),
        ],
      },
    );

    final provider = RecentActivityProvider();

    await provider.refresh(force: true);

    expect(provider.activities, hasLength(1));
    expect(provider.unreadActivities, isEmpty);
    expect(provider.activities.first.isRead, isTrue);
  });
}
