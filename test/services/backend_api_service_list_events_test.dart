import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: const <String, String>{'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('listEvents only reads /api/events and returns served events untouched',
      () async {
    final requests = <Uri>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url);
      return _json({
        'success': true,
        'data': {
          'events': [
            {'id': 'event-1', 'title': 'One', 'host_user_id': 'host-1'},
            {'id': 'event-2', 'title': 'Two', 'institution_id': 'inst-9'},
          ],
        },
      });
    }));

    final events = await BackendApiService().listEvents(limit: 20);

    expect(events.map((e) => e['id']), <Object?>['event-1', 'event-2']);
    expect(requests, isNotEmpty);
    for (final uri in requests) {
      expect(uri.path, '/api/events');
      expect(uri.queryParameters.keys, isNot(contains('institutionId')));
    }
  });

  test('listEvents never calls an institution events route', () async {
    final paths = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      paths.add(request.url.path);
      return _json({
        'success': true,
        'data': {'events': <Object>[]}
      });
    }));

    await BackendApiService().listEvents(hostUserId: 'host-1', limit: 10);

    expect(
      paths.where((p) => p.startsWith('/api/institutions')),
      isEmpty,
    );
  });

  test('listEvents reports an unavailable endpoint as empty, not as events',
      () async {
    BackendApiService().setHttpClient(MockClient((request) async {
      return _json({'success': false, 'error': 'not found'}, 404);
    }));

    final events = await BackendApiService().listEvents(limit: 10);

    expect(events, isEmpty);
  });
}
