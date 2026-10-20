import 'dart:convert';
import 'dart:io';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendApiService api;

  setUp(() {
    api = BackendApiService();
  });

  tearDown(() {
    api.setHttpClient(createPlatformHttpClient());
    api.setAuthTokenForTesting(null);
  });

  test('parses the shared account notification summary contract fixture', () {
    final fixture = jsonDecode(
      File(
        'test/fixtures/notifications_unread_summary.contract.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;

    final summary = NotificationUnreadSummary.fromJson(fixture);

    expect(summary.notificationsUnreadCount, 2);
    expect(summary.messagesUnreadCount, 1);
    expect(summary.totalUnreadCount, 3);
    expect(summary.generatedAt, DateTime.utc(2026, 10, 20, 12));
  });

  test(
    'requests the authoritative route and parses the serialized response',
    () async {
      api.setAuthTokenForTesting('test-token');
      var requestedPath = '';
      api.setHttpClient(
        MockClient((request) async {
          requestedPath = request.url.path;
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'notificationUnreadCount': 4,
              'messageUnreadCount': 2,
              'totalUnreadCount': 6,
              'generatedAt': '2026-10-20T12:00:00.000Z',
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final summary = await api.getUnreadNotificationSummary();

      expect(requestedPath, '/api/notifications/unread-summary');
      expect(summary?.notificationsUnreadCount, 4);
      expect(summary?.messagesUnreadCount, 2);
      expect(summary?.totalUnreadCount, 6);
    },
  );

  test('keeps the previous snapshot on a failed request', () async {
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(
      MockClient((_) async => http.Response('unavailable', 503)),
    );

    expect(await api.getUnreadNotificationSummary(), isNull);
  });
}
