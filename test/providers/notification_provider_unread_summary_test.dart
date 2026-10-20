import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> _summary(int notifications, int messages) =>
    <String, Object?>{
      'success': true,
      'notificationUnreadCount': notifications,
      'messageUnreadCount': messages,
      'totalUnreadCount': notifications + messages,
      'generatedAt': '2026-10-20T12:00:00.000Z',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;
  final providers = <NotificationProvider>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService();
    api.setAuthTokenForTesting('test-token');
    providers.clear();
  });

  tearDown(() {
    for (final provider in providers) {
      provider.dispose();
    }
    api.setHttpClient(createPlatformHttpClient());
    api.setAuthTokenForTesting(null);
  });

  NotificationProvider makeProvider() {
    final provider = NotificationProvider()
      ..setAuthenticatedSessionForTesting();
    providers.add(provider);
    return provider;
  }

  test('new socket snapshot wins over an older pending REST snapshot',
      () async {
    final requestStarted = Completer<void>();
    final staleResponse = Completer<http.Response>();
    api.setHttpClient(
      MockClient((request) async {
        expect(request.url.path, '/api/notifications/unread-summary');
        requestStarted.complete();
        return staleResponse.future;
      }),
    );
    final provider = makeProvider();

    final pendingRefresh = provider.refresh(force: true);
    await requestStarted.future;
    provider.handleUnreadSummaryForTesting(_summary(4, 3));
    staleResponse.complete(
      http.Response(jsonEncode(_summary(1, 0)), 200),
    );
    await pendingRefresh;

    expect(provider.unreadCount, 4);
    expect(provider.messageUnreadCount, 3);
    expect(provider.totalUnreadCount, 7);
  });

  test('notification read events refresh the authoritative summary', () async {
    var requestCount = 0;
    api.setHttpClient(
      MockClient((request) async {
        expect(request.url.path, '/api/notifications/unread-summary');
        requestCount++;
        return http.Response(jsonEncode(_summary(2, 1)), 200);
      }),
    );
    final provider = makeProvider();

    provider.handleNotificationForTesting(<String, dynamic>{
      'type': 'notification:read',
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(requestCount, 1);
    expect(provider.unreadCount, 2);
    expect(provider.messageUnreadCount, 1);
    expect(provider.totalUnreadCount, 3);
  });

  test('walletless socket reconnect reloads the account-scoped summary',
      () async {
    var requestCount = 0;
    api.setHttpClient(
      MockClient((request) async {
        expect(request.url.path, '/api/notifications/unread-summary');
        requestCount++;
        return http.Response(jsonEncode(_summary(3, 2)), 200);
      }),
    );
    final provider = makeProvider();

    await provider.handleSocketReconnectForTesting();

    expect(requestCount, 1);
    expect(provider.unreadCount, 3);
    expect(provider.messageUnreadCount, 2);
    expect(provider.totalUnreadCount, 5);
  });

  test('socket notifications addressed to another account change nothing',
      () async {
    var requestCount = 0;
    api.setHttpClient(
      MockClient((request) async {
        requestCount++;
        return http.Response(jsonEncode(_summary(9, 9)), 200);
      }),
    );
    final provider = NotificationProvider()
      ..setAuthenticatedSessionForTesting(accountId: 'user-1');
    providers.add(provider);

    provider.handleNotificationForTesting(<String, dynamic>{
      'type': 'notification:read',
      'recipientUserId': 'user-2',
    });
    provider.handleNotificationForTesting(<String, dynamic>{
      'type': 'comment',
      'recipient_user_id': 'user-2',
      'data': <String, dynamic>{'postId': 'post-1'},
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(requestCount, 0);
    expect(provider.unreadCount, 0);
    expect(provider.messageUnreadCount, 0);
    expect(provider.hasNew, isFalse);

    provider.handleNotificationForTesting(<String, dynamic>{
      'type': 'notification:read',
      'recipientUserId': 'user-1',
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(requestCount, 1);
    expect(provider.unreadCount, 9);
  });
}
