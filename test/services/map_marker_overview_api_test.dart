import 'dart:convert';

import 'package:art_kubus/models/map_marker_overview.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/map_marker_service.dart';
import 'package:art_kubus/services/public_fallback_service.dart';
import 'package:art_kubus/utils/geo_bounds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
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

  http.Response overviewResponse() => http.Response(
        jsonEncode(<String, Object?>{
          'success': true,
          'version': 1,
          'zoom': 4,
          'level': 8,
          'total': 401,
          'count': 2,
          'data': <Object?>[
            <String, Object?>{
              'id': 'ov8:130:75',
              'lat': 48.2,
              'lng': 16.37,
              'count': 400,
              'dominantType': 'artwork',
              'types': <String, Object?>{'artwork': 380, 'streetArt': 20},
            },
            <String, Object?>{
              'id': 'ov8:128:79',
              'lat': 41.9,
              'lng': 12.5,
              'count': 1,
              'dominantType': 'artwork',
              'types': <String, Object?>{'artwork': 1},
              'markerId': 'marker-1',
            },
          ],
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );

  test(
      'the far map asks for the overview of the viewport, never the 300 nearest '
      'detailed markers', () async {
    final requests = <Uri>[];
    BackendApiService().setHttpClient(
      MockClient((request) async {
        requests.add(request.url);
        expect(request.method, 'GET');
        expect(request.headers.containsKey('authorization'), isFalse);
        return overviewResponse();
      }),
    );

    final service = MapMarkerService.createForTest();
    final overview = await service.loadMarkerOverview(
      bounds:
          const GeoBounds(south: 33.3, west: -38.6, north: 68.4, east: 66.6),
      zoom: 4,
    );

    expect(requests, hasLength(1));
    final url = requests.single;
    expect(url.path, '/api/art-markers/overview');
    expect(url.queryParameters['minLat'], '33.3');
    expect(url.queryParameters['maxLat'], '68.4');
    expect(url.queryParameters['minLng'], '-38.6');
    expect(url.queryParameters['maxLng'], '66.6');
    expect(url.queryParameters['zoom'], '4.00');
    // It is not the detailed bounds query: no centre, no limit.
    expect(url.queryParameters.containsKey('limit'), isFalse);
    expect(url.queryParameters.containsKey('lat'), isFalse);

    expect(overview.nodes, hasLength(2));
    expect(overview.total, 401);
    expect(overview.nodes.first.count, 400);
    expect(overview.nodes.first.types['streetArt'], 20);
    expect(overview.nodes.last.markerId, 'marker-1');
  });

  test('an unavailable overview endpoint throws, so the caller falls back',
      () async {
    BackendApiService().setHttpClient(
      MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{'success': false, 'error': 'Not found'}),
          404,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    await expectLater(
      BackendApiService().getMarkerOverview(
        minLat: 40,
        maxLat: 50,
        minLng: 0,
        maxLng: 20,
        zoom: 4,
      ),
      throwsA(anything),
    );
  });

  test('a malformed overview response is an error, not an empty map', () async {
    BackendApiService().setHttpClient(
      MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{'success': true, 'data': 'nope'}),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    await expectLater(
      BackendApiService().getMarkerOverview(
        minLat: 40,
        maxLat: 50,
        minLng: 0,
        maxLng: 20,
        zoom: 4,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('the model skips invalid nodes and keeps the exact total', () {
    final overview = MapMarkerOverview.tryParse(<String, Object?>{
      'zoom': 3,
      'level': 6,
      'data': <Object?>[
        <String, Object?>{'id': 'a', 'lat': 10, 'lng': 20, 'count': 5},
        <String, Object?>{'id': 'b', 'lat': 91, 'lng': 20, 'count': 5},
        <String, Object?>{'id': '', 'lat': 10, 'lng': 20, 'count': 5},
        <String, Object?>{'id': 'c', 'lat': 10, 'lng': 20, 'count': 0},
        'garbage',
        <String, Object?>{'id': 'd', 'lat': -10, 'lng': -20, 'count': 7},
      ],
    })!;
    expect(overview.nodes.map((node) => node.id), <String>['a', 'd']);
    expect(overview.total, 12);
    expect(overview.nodes.first.dominantType, 'unknown');
  });

  group('content layers restrict a node without lying about its count', () {
    const node = MapMarkerOverviewNode(
      id: 'ov8:1:1',
      position: LatLng(0, 0),
      count: 400,
      dominantType: 'artwork',
      types: <String, int>{'artwork': 380, 'streetArt': 20},
    );

    test('everything visible keeps the node as it is', () {
      expect(node.restrictedTo((_) => true), same(node));
    });

    test('hiding the dominant type leaves the exact remainder', () {
      final restricted = node.restrictedTo((type) => type != 'artwork')!;
      expect(restricted.count, 20);
      expect(restricted.dominantType, 'streetArt');
      expect(restricted.types, <String, int>{'streetArt': 20});
    });

    test('nothing visible removes the node', () {
      expect(node.restrictedTo((_) => false), isNull);
    });

    test('a single remaining marker exposes its id', () {
      const mixed = MapMarkerOverviewNode(
        id: 'ov8:2:2',
        position: LatLng(0, 0),
        count: 3,
        dominantType: 'artwork',
        types: <String, int>{'artwork': 2, 'event': 1},
        markerId: null,
      );
      expect(mixed.restrictedTo((type) => type == 'event')!.count, 1);
    });
  });
}
