import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/public_fallback_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PublicFallbackService().resetForTesting();
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService().setHttpClient(http.Client());
  });

  test(
    'getArtMarkersByArtwork uses the typed public marker endpoint',
    () async {
      const artworkId = '11111111-1111-4111-8111-111111111111';
      var requestCount = 0;
      BackendApiService().setHttpClient(
        MockClient((request) async {
          requestCount += 1;
          expect(request.method, 'GET');
          expect(request.url.path, '/api/art-markers/by-artwork/$artworkId');
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'count': 1,
              'data': <Object?>[
                <String, Object?>{
                  'id': '22222222-2222-4222-8222-222222222222',
                  'artworkId': artworkId,
                  'name': 'Artwork marker',
                  'description': 'Marker description',
                  'latitude': 46.0569,
                  'longitude': 14.5058,
                  'markerType': 'artwork',
                  'type': 'artwork',
                  'category': 'Artwork',
                  'createdAt': '2026-07-01T10:00:00.000Z',
                  'createdBy': 'system',
                  'isPublic': true,
                  'isActive': true,
                },
              ],
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final markers = await BackendApiService().getArtMarkersByArtwork(
        artworkId,
      );

      expect(requestCount, 1);
      expect(markers, hasLength(1));
      expect(markers.single.id, '22222222-2222-4222-8222-222222222222');
      expect(markers.single.artworkId, artworkId);
      expect(markers.single.isPublic, isTrue);
      expect(markers.single.isActive, isTrue);
    },
  );

  test(
    'getArtMarkersByArtwork skips transport for a blank identifier',
    () async {
      var requestCount = 0;
      BackendApiService().setHttpClient(
        MockClient((request) async {
          requestCount += 1;
          return http.Response('{}', 200);
        }),
      );

      final markers = await BackendApiService().getArtMarkersByArtwork('   ');

      expect(markers, isEmpty);
      expect(requestCount, 0);
    },
  );
}
