import 'dart:convert';

import 'package:art_kubus/providers/events_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('EventsProvider retries after provisional events endpoint 404',
      () async {
    final api = BackendApiService();
    var eventRequests = 0;
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/events') {
          return http.Response('Unexpected request ${request.url}', 500);
        }
        eventRequests += 1;
        if (eventRequests == 1) {
          return http.Response('Not Found', 404);
        }
        return _jsonResponse(<String, Object?>{
          'data': <String, Object?>{
            'events': <Object?>[
              <String, Object?>{
                'id': 'event-1',
                'title': 'Recovered Event',
                'starts_at': '2026-08-01T18:00:00.000Z',
              },
            ],
          },
        });
      }),
    );
    final provider = EventsProvider(api: api);
    addTearDown(provider.dispose);

    await provider.loadEvents(refresh: true);

    expect(provider.events, isEmpty);
    expect(provider.error, isNull);
    expect(api.eventsApiAvailable, isNull);

    await provider.loadEvents(refresh: true);

    expect(eventRequests, 2);
    expect(provider.error, isNull);
    expect(provider.events.single.id, 'event-1');
    expect(api.eventsApiAvailable, isTrue);
  });

  test('ExhibitionsProvider retries after provisional exhibitions endpoint 404',
      () async {
    final api = BackendApiService();
    var exhibitionRequests = 0;
    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/exhibitions') {
          return http.Response('Unexpected request ${request.url}', 500);
        }
        exhibitionRequests += 1;
        if (exhibitionRequests == 1) {
          return http.Response('Not Found', 404);
        }
        return _jsonResponse(<String, Object?>{
          'data': <String, Object?>{
            'exhibitions': <Object?>[
              <String, Object?>{
                'id': 'exhibition-1',
                'title': 'Recovered Exhibition',
                'starts_at': '2026-08-01T18:00:00.000Z',
              },
            ],
          },
        });
      }),
    );
    final provider = ExhibitionsProvider(api: api);
    addTearDown(provider.dispose);

    await provider.loadExhibitions(refresh: true);

    expect(provider.exhibitions, isEmpty);
    expect(provider.error, isNotNull);
    expect(api.exhibitionsApiAvailable, isNull);

    await provider.loadExhibitions(refresh: true);

    expect(exhibitionRequests, 2);
    expect(provider.error, isNull);
    expect(provider.exhibitions.single.id, 'exhibition-1');
    expect(api.exhibitionsApiAvailable, isTrue);
  });
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}
