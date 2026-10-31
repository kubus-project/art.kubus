import 'package:art_kubus/providers/recent_activity_provider.dart';
import 'package:art_kubus/services/account_cache_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/account_notifications_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    BackendApiService().resetCredentialStoreForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AccountCacheStore.resetForTesting();
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() async {
    BackendApiService().setAuthTokenForTesting(null);
    await AccountCacheStore.resetForTesting();
  });

  test('in-app notifications default to unread when no read flags are present',
      () async {
    await storeInAppNotifications(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'comment',
        'title': 'New comment',
        'body': 'Alice: Nice artwork!',
        'payload': <String, dynamic>{'postId': 'post-1'},
        'timestamp': hoursAgo(2),
      },
    ]);

    final provider = RecentActivityProvider();

    await provider.refresh(force: true);

    expect(provider.activities, hasLength(1));
    expect(provider.unreadActivities, hasLength(1));
    expect(provider.activities.first.isRead, isFalse);
    expect(provider.activities.first.description, 'Alice: Nice artwork!');
  });

  test('explicit read flag still takes precedence for in-app notifications',
      () async {
    await storeInAppNotifications(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'reward',
        'title': 'Reward granted',
        'body': '+10 KUB8',
        'payload': <String, dynamic>{'amount': 10},
        'timestamp': hoursAgo(1),
        'isRead': true,
      },
    ]);

    final provider = RecentActivityProvider();

    await provider.refresh(force: true);

    expect(provider.activities, hasLength(1));
    expect(provider.unreadActivities, isEmpty);
    expect(provider.activities.first.isRead, isTrue);
  });

  test('generic reward amount is not presented as KUB8', () async {
    await storeInAppNotifications(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'reward',
        'title': 'Recognition recorded',
        'data': <String, dynamic>{'amount': 5},
        'timestamp': hoursAgo(1),
      },
    ]);

    final provider = RecentActivityProvider();
    await provider.refresh(force: true);

    expect(provider.activities.single.description, 'You have new recognition');
    expect(provider.activities.single.description, isNot(contains('KUB8')));
  });

  test('explicit KUB8 reward and achievement remain correctly denominated',
      () async {
    await storeInAppNotifications(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'reward',
        'data': <String, dynamic>{'amount': 5, 'currency': 'KUB8'},
        'timestamp': hoursAgo(1),
      },
      <String, dynamic>{
        'type': 'achievement',
        'data': <String, dynamic>{'title': 'Archive work', 'rewardTokens': 7},
        'timestamp': hoursAgo(2),
      },
      <String, dynamic>{
        'type': 'kub8',
        'data': <String, dynamic>{'amount': 3},
        'timestamp': hoursAgo(3),
      },
    ]);

    final provider = RecentActivityProvider();
    await provider.refresh(force: true);

    expect(provider.activities.first.description, '+5 KUB8');
    expect(provider.activities[1].description, 'Archive work (+7 KUB8)');
    expect(provider.activities.last.description, '+3 KUB8');
  });

  test('another account never sees a signed-in account\'s notifications',
      () async {
    await storeInAppNotifications(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'comment',
        'title': 'New comment',
        'body': 'Private to the first account',
        'timestamp': hoursAgo(1),
      },
    ]);
    BackendApiService().setAuthTokenForTesting(null);

    final provider = RecentActivityProvider();
    await provider.refresh(force: true);

    expect(provider.activities, isEmpty);
  });
}
