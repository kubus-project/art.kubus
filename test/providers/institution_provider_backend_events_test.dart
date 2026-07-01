import 'dart:convert';

import 'package:art_kubus/models/institution.dart';
import 'package:art_kubus/providers/institution_provider.dart';
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

  test('initialize parses backend-shaped events through institution adapter',
      () async {
    final requests = <String>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/api/institutions') {
        return _jsonResponse({
          'institutions': [
            _institutionPayload(id: 'inst-1'),
          ],
        });
      }
      if (request.url.path == '/api/events') {
        return _jsonResponse({
          'data': {
            'events': [
              {
                'id': 'event-1',
                'title': 'Backend Event',
                'description': 'From /api/events',
                'type': 'workshop',
                'category': 'digital',
                'institution_id': 'inst-1',
                'starts_at': '2026-08-01T18:00:00.000Z',
                'ends_at': '2026-08-01T20:00:00.000Z',
                'location_name': 'Studio 2',
                'lat': 46.0511,
                'lng': 14.5051,
                'cover_url': '/uploads/events/backend.png',
                'created_at': '2026-07-01T10:00:00.000Z',
                'host_user_id': 'host-1',
              },
            ],
          },
        });
      }
      return http.Response('Unexpected request ${request.url}', 500);
    }));

    final provider = InstitutionProvider();
    await provider.initialize();

    expect(requests, containsAll(<String>['/api/institutions', '/api/events']));
    expect(provider.events, hasLength(1));
    final event = provider.events.single;
    expect(event.id, 'event-1');
    expect(event.type, EventType.workshop);
    expect(event.category, EventCategory.digital);
    expect(event.institutionId, 'inst-1');
    expect(event.institution?.id, 'inst-1');
    expect(event.location, 'Studio 2');
    expect(event.imageUrls, contains('/uploads/events/backend.png'));
  });
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

Map<String, Object?> _institutionPayload({required String id}) {
  return {
    'id': id,
    'name': 'Kubus Gallery',
    'description': 'Institution',
    'type': 'gallery',
    'address': 'Main Street',
    'latitude': 46.0511,
    'longitude': 14.5051,
    'contactEmail': 'hello@example.com',
    'website': 'https://example.com',
    'imageUrls': <String>[],
    'stats': {
      'totalVisitors': 0,
      'activeEvents': 1,
      'artworkViews': 0,
      'revenue': 0,
      'visitorGrowth': 0,
      'revenueGrowth': 0,
    },
    'isVerified': true,
    'createdAt': '2026-07-01T10:00:00.000Z',
  };
}
