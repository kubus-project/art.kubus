import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/walking_directions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const _origin = LatLng(46.05000, 14.50000);
const _east = LatLng(46.05000, 14.50100);
const _destination = LatLng(46.05100, 14.50100);

Map<String, Object> _elementNode(int id, LatLng point) => <String, Object>{
      'type': 'node',
      'id': id,
      'lat': point.latitude,
      'lon': point.longitude,
    };

Map<String, Object> _elementWay(
  int id,
  List<int> nodes, {
  String highway = 'footway',
  String name = '',
  Map<String, String> tags = const <String, String>{},
}) =>
    <String, Object>{
      'type': 'way',
      'id': id,
      'nodes': nodes,
      'tags': <String, String>{
        'highway': highway,
        if (name.isNotEmpty) 'name': name,
        ...tags,
      },
    };

http.Response _overpassResponse(List<Map<String, Object>> elements) =>
    http.Response(
      jsonEncode(<String, Object>{'elements': elements}),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );

WalkingDirectionsService _service(
  http.Client client, {
  double maximumSnapDistanceMeters = 300,
  Iterable<String> endpoints = const <String>[
    'https://overpass.test/api/interpreter',
  ],
  Duration timeout = const Duration(seconds: 20),
  int maximumResponseBytes = 8 * 1024 * 1024,
}) =>
    WalkingDirectionsService(
      client: client,
      endpoints: endpoints,
      timeout: timeout,
      minimumRequestInterval: Duration.zero,
      maximumSnapDistanceMeters: maximumSnapDistanceMeters,
      maximumResponseBytes: maximumResponseBytes,
    );

void main() {
  group('WalkingDirectionsService', () {
    test('posts a bounded Overpass query and calculates the route locally',
        () async {
      late http.Request request;
      final client = MockClient((incoming) async {
        request = incoming;
        return _overpassResponse(<Map<String, Object>>[
          _elementNode(1, _origin),
          _elementNode(2, _east),
          _elementNode(3, _destination),
          _elementWay(10, <int>[1, 2], name: 'Gallery Walk'),
          _elementWay(11, <int>[2, 3], name: 'Museum Street'),
        ]);
      });
      final service = _service(client);

      final route = await service.route(
        origin: _origin,
        destination: _destination,
      );

      expect(request.method, 'POST');
      expect(request.url, Uri.parse('https://overpass.test/api/interpreter'));
      expect(
        request.bodyFields['data'],
        contains('way["highway"~"^(footway|path|pedestrian|steps|'),
      );
      expect(
        request.bodyFields['data'],
        contains('["foot"~"^(yes|designated|permissive)\$",i]'),
      );
      expect(
        request.bodyFields['data'],
        isNot(contains('way["highway"]["area"!="yes"]')),
      );
      expect(request.bodyFields['data'], contains('[maxsize:8388608]'));
      expect(route.points, contains(_east));
      expect(route.points.first, _origin);
      expect(route.points.last, _destination);
      expect(route.distanceMeters, greaterThan(150));
      expect(route.durationSeconds, greaterThan(0));
      expect(route.steps.first.type, 'depart');
      expect(route.steps.last.type, 'arrive');
      expect(
        route.steps.any(
            (step) => step.type == 'turn' && step.roadName == 'Museum Street'),
        isTrue,
      );
      service.dispose();
    });

    test('ignores prohibited shortcuts instead of drawing a direct fallback',
        () async {
      const shortcut = LatLng(46.05050, 14.50050);
      final client = MockClient((_) async => _overpassResponse(
            <Map<String, Object>>[
              _elementNode(1, _origin),
              _elementNode(2, _east),
              _elementNode(3, _destination),
              _elementNode(4, shortcut),
              _elementWay(10, <int>[1, 2, 3], name: 'Legal Walk'),
              _elementWay(
                20,
                <int>[1, 4, 3],
                name: 'Private Shortcut',
                tags: const <String, String>{'foot': 'private'},
              ),
            ],
          ));
      final service = _service(client);

      final route = await service.route(
        origin: _origin,
        destination: _destination,
      );

      expect(route.points, contains(_east));
      expect(route.points, isNot(contains(shortcut)));
      service.dispose();
    });

    test('reuses a downloaded graph for reroutes inside its bounded area',
        () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests += 1;
        return _overpassResponse(<Map<String, Object>>[
          _elementNode(1, _origin),
          _elementNode(2, _east),
          _elementNode(3, _destination),
          _elementWay(10, <int>[1, 2, 3]),
        ]);
      });
      final service = _service(client);

      await service.route(origin: _origin, destination: _destination);
      await service.route(origin: _east, destination: _destination);

      expect(requests, 1);
      service.dispose();
    });

    test('honors pedestrian one-way direction', () async {
      final client = MockClient((_) async => _overpassResponse(
            <Map<String, Object>>[
              _elementNode(1, _origin),
              _elementNode(2, _east),
              _elementNode(3, _destination),
              _elementWay(
                10,
                <int>[1, 2, 3],
                tags: const <String, String>{'oneway:foot': 'yes'},
              ),
            ],
          ));
      final service = _service(client, maximumSnapDistanceMeters: 20);

      await expectLater(
        service.route(origin: _destination, destination: _origin),
        throwsA(
          isA<WalkingDirectionsException>().having(
            (error) => error.message,
            'message',
            contains('No connected walking route'),
          ),
        ),
      );
      service.dispose();
    });

    test('throws when the graph is disconnected and never returns two points',
        () async {
      const nearDestination = LatLng(46.05100, 14.50080);
      final client = MockClient((_) async => _overpassResponse(
            <Map<String, Object>>[
              _elementNode(1, _origin),
              _elementNode(2, _east),
              _elementNode(3, nearDestination),
              _elementNode(4, _destination),
              _elementWay(10, <int>[1, 2]),
              _elementWay(11, <int>[3, 4]),
            ],
          ));
      final service = _service(client, maximumSnapDistanceMeters: 20);

      await expectLater(
        service.route(origin: _origin, destination: _destination),
        throwsA(
          isA<WalkingDirectionsException>().having(
            (error) => error.type,
            'type',
            WalkingDirectionsErrorType.noRoute,
          ),
        ),
      );
      service.dispose();
    });

    test('rejects non-HTTPS graph endpoints', () {
      expect(
        () => WalkingDirectionsService(
          endpoints: const <String>[
            'http://overpass.test/api/interpreter',
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects an empty graph endpoint list', () {
      expect(
        () => WalkingDirectionsService(endpoints: const <String>[]),
        throwsArgumentError,
      );
    });

    test('rejects routes outside the bounded client-navigation range',
        () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests += 1;
        return _overpassResponse(const <Map<String, Object>>[]);
      });
      final service = WalkingDirectionsService(
        client: client,
        endpoints: const <String>[
          'https://overpass.test/api/interpreter',
        ],
        maximumRouteDistanceMeters: 100,
      );

      await expectLater(
        service.route(origin: _origin, destination: _destination),
        throwsA(
          isA<WalkingDirectionsException>().having(
            (error) => error.type,
            'type',
            WalkingDirectionsErrorType.routeTooLong,
          ),
        ),
      );
      expect(requests, 0);
      service.dispose();
    });

    test('rejects malformed Overpass responses', () async {
      final client = MockClient((_) async => http.Response('not json', 200));
      final service = _service(client);

      await expectLater(
        service.route(origin: _origin, destination: _destination),
        throwsA(
          isA<WalkingDirectionsException>().having(
            (error) => error.message,
            'message',
            contains('response was invalid'),
          ),
        ),
      );
      service.dispose();
    });

    test('uses configured endpoints in order after a retryable response',
        () async {
      final requested = <Uri>[];
      final client = MockClient((request) async {
        requested.add(request.url);
        if (requested.length == 1) {
          return http.Response('temporarily unavailable', 503);
        }
        return _overpassResponse(<Map<String, Object>>[
          _elementNode(1, _origin),
          _elementNode(2, _east),
          _elementNode(3, _destination),
          _elementWay(10, <int>[1, 2, 3]),
        ]);
      });
      final service = _service(
        client,
        endpoints: const <String>[
          'https://first-overpass.test/api/interpreter',
          'https://second-overpass.test/api/interpreter',
        ],
      );

      final route = await service.route(
        origin: _origin,
        destination: _destination,
      );

      expect(requested, <Uri>[
        Uri.parse('https://first-overpass.test/api/interpreter'),
        Uri.parse('https://second-overpass.test/api/interpreter'),
      ]);
      expect(route.points, contains(_east));
      service.dispose();
    });

    test('default endpoint list fails over between public OSM instances',
        () async {
      final requested = <Uri>[];
      final client = MockClient((request) async {
        requested.add(request.url);
        if (requested.length == 1) return http.Response('busy', 429);
        return _overpassResponse(<Map<String, Object>>[
          _elementNode(1, _origin),
          _elementNode(2, _east),
          _elementNode(3, _destination),
          _elementWay(10, <int>[1, 2, 3]),
        ]);
      });
      final service = WalkingDirectionsService(
        client: client,
        minimumRequestInterval: Duration.zero,
        maximumSnapDistanceMeters: 300,
      );

      await service.route(origin: _origin, destination: _destination);

      expect(requested, <Uri>[
        Uri.parse('https://overpass-api.de/api/interpreter'),
        Uri.parse('https://overpass.private.coffee/api/interpreter'),
      ]);
      service.dispose();
    });

    for (final status in <int>[406, 408, 429, 500, 503, 599]) {
      test('fails over after retryable HTTP $status', () async {
        var requests = 0;
        final client = MockClient((_) async {
          requests += 1;
          if (requests == 1) return http.Response('retry', status);
          return _overpassResponse(<Map<String, Object>>[
            _elementNode(1, _origin),
            _elementNode(2, _east),
            _elementNode(3, _destination),
            _elementWay(10, <int>[1, 2, 3]),
          ]);
        });
        final service = _service(
          client,
          endpoints: const <String>[
            'https://first-overpass.test/api/interpreter',
            'https://second-overpass.test/api/interpreter',
          ],
        );

        await service.route(origin: _origin, destination: _destination);

        expect(requests, 2);
        service.dispose();
      });
    }

    for (final status in <int>[400, 401, 403, 404, 405, 409, 422]) {
      test('does not fail over after non-retryable HTTP $status', () async {
        var requests = 0;
        final client = MockClient((_) async {
          requests += 1;
          return http.Response('do not retry', status);
        });
        final service = _service(
          client,
          endpoints: const <String>[
            'https://first-overpass.test/api/interpreter',
            'https://second-overpass.test/api/interpreter',
          ],
        );

        await expectLater(
          service.route(origin: _origin, destination: _destination),
          throwsA(
            isA<WalkingDirectionsException>()
                .having(
                  (error) => error.type,
                  'type',
                  WalkingDirectionsErrorType.sourceHttp,
                )
                .having((error) => error.statusCode, 'statusCode', status)
                .having(
                  (error) => error.endpoint,
                  'endpoint',
                  Uri.parse('https://first-overpass.test/api/interpreter'),
                ),
          ),
        );
        expect(requests, 1);
        service.dispose();
      });
    }

    test('fails over after a transport error and preserves the final type',
        () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests += 1;
        throw http.ClientException('offline', request.url);
      });
      final service = _service(
        client,
        endpoints: const <String>[
          'https://first-overpass.test/api/interpreter',
          'https://second-overpass.test/api/interpreter',
        ],
      );

      await expectLater(
        service.route(origin: _origin, destination: _destination),
        throwsA(
          isA<WalkingDirectionsException>()
              .having(
                (error) => error.type,
                'type',
                WalkingDirectionsErrorType.sourceTransport,
              )
              .having(
                (error) => error.endpoint,
                'endpoint',
                Uri.parse('https://second-overpass.test/api/interpreter'),
              ),
        ),
      );
      expect(requests, 2);
      service.dispose();
    });

    test('fails over after a timeout and preserves the final type', () async {
      var requests = 0;
      final client = MockClient((_) {
        requests += 1;
        return Completer<http.Response>().future;
      });
      final service = _service(
        client,
        endpoints: const <String>[
          'https://first-overpass.test/api/interpreter',
          'https://second-overpass.test/api/interpreter',
        ],
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        service.route(origin: _origin, destination: _destination),
        throwsA(
          isA<WalkingDirectionsException>()
              .having(
                (error) => error.type,
                'type',
                WalkingDirectionsErrorType.sourceTimeout,
              )
              .having(
                (error) => error.endpoint,
                'endpoint',
                Uri.parse('https://second-overpass.test/api/interpreter'),
              ),
        ),
      );
      expect(requests, 2);
      service.dispose();
    });

    test('fails over after a successful but malformed response', () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests += 1;
        if (requests == 1) return http.Response('not json', 200);
        return _overpassResponse(<Map<String, Object>>[
          _elementNode(1, _origin),
          _elementNode(2, _east),
          _elementNode(3, _destination),
          _elementWay(10, <int>[1, 2, 3]),
        ]);
      });
      final service = _service(
        client,
        endpoints: const <String>[
          'https://first-overpass.test/api/interpreter',
          'https://second-overpass.test/api/interpreter',
        ],
      );

      final route = await service.route(
        origin: _origin,
        destination: _destination,
      );
      expect(route.points, isNotEmpty);
      expect(requests, 2);
      service.dispose();
    });

    test('stops buffering an oversized response and uses the fallback',
        () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests += 1;
        if (requests == 1) {
          final oversized = jsonEncode(<String, Object>{
            'elements': List<String>.filled(2048, 'x').join(),
          });
          return http.Response(oversized, 200);
        }
        return _overpassResponse(<Map<String, Object>>[
          _elementNode(1, _origin),
          _elementNode(2, _east),
          _elementNode(3, _destination),
          _elementWay(10, <int>[1, 2, 3]),
        ]);
      });
      final service = _service(
        client,
        endpoints: const <String>[
          'https://first-overpass.test/api/interpreter',
          'https://second-overpass.test/api/interpreter',
        ],
        maximumResponseBytes: 512,
      );

      final route = await service.route(
        origin: _origin,
        destination: _destination,
      );
      expect(route.points, isNotEmpty);
      expect(requests, 2);
      service.dispose();
    });

    test('cancels an obsolete graph request when a newer route starts',
        () async {
      final client = _AbortAwareClient(
        response: _overpassResponse(<Map<String, Object>>[
          _elementNode(1, _origin),
          _elementNode(2, _east),
          _elementNode(3, _destination),
          _elementWay(10, <int>[1, 2, 3]),
        ]),
      );
      final service = _service(client);

      final obsolete = service.route(
        origin: _origin,
        destination: _destination,
      );
      await client.firstRequestStarted.future;
      final current = service.route(origin: _east, destination: _destination);

      await expectLater(
        obsolete,
        throwsA(
          isA<WalkingDirectionsException>().having(
            (error) => error.type,
            'type',
            WalkingDirectionsErrorType.sourceCancelled,
          ),
        ),
      );
      expect((await current).points.last, _destination);
      expect(client.requests, 2);
      service.dispose();
    });
  });
}

class _AbortAwareClient extends http.BaseClient {
  _AbortAwareClient({required this.response});

  final http.Response response;
  final Completer<void> firstRequestStarted = Completer<void>();
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests += 1;
    if (requests > 1) return Future<http.StreamedResponse>.value(_streamed());
    firstRequestStarted.complete();
    final result = Completer<http.StreamedResponse>();
    if (request case http.Abortable(:final abortTrigger?)) {
      unawaited(
        abortTrigger.then((_) {
          if (!result.isCompleted) {
            result.completeError(http.RequestAbortedException(request.url));
          }
        }),
      );
    }
    return result.future;
  }

  http.StreamedResponse _streamed() => http.StreamedResponse(
        Stream<List<int>>.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
}
