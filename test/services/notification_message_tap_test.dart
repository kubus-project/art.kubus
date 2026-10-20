import 'dart:convert';

import 'package:art_kubus/services/notification_handler.dart';
import 'package:art_kubus/services/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'direct-message tap preserves its conversation ID for the app route',
    () {
      final handler = NotificationHandler();
      String? route;
      Map<String, dynamic>? arguments;
      handler.onNavigate = (value, params) {
        route = value;
        arguments = params;
      };

      handler.handleNotificationPayloadForTesting(
        jsonEncode(<String, Object?>{
          'type': 'direct_message',
          'eventId': 'message-17',
          'actionUrl': 'app://messages/conversation-42',
        }),
      );

      expect(route, '/messages');
      expect(arguments, <String, dynamic>{
        'conversationId': 'conversation-42',
        'eventId': 'message-17',
      });
      handler.onNavigate = null;
    },
  );

  test(
    'terminated-app notification tap waits until a route listener attaches',
    () async {
      final service = PushNotificationService();
      const payload = '{"type":"direct_message","conversationId":"c-1"}';
      final received = <String>[];
      void listener(String value) => received.add(value);

      service.queueLaunchTapForTesting(payload);
      expect(received, isEmpty);

      service.addOnNotificationTapListener(listener);
      await Future<void>.delayed(Duration.zero);
      expect(received, <String>[payload]);

      service.removeOnNotificationTapListener(listener);
    },
  );

  test('rejects oversized conversation route IDs', () {
    final handler = NotificationHandler();
    final routes = <String>[];
    handler.onNavigate = (route, _) => routes.add(route);

    handler.handleNotificationPayloadForTesting(
      jsonEncode(<String, Object?>{
        'type': 'direct_message',
        'conversationId': List<String>.filled(129, 'c').join(),
      }),
    );

    expect(routes, isEmpty);
    handler.onNavigate = null;
  });
}
