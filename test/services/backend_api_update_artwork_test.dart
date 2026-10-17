import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The artwork save contract, end to end from HTTP status to provider result:
///
/// * a 200 with an artwork is a confirmed write;
/// * a 200 without a usable artwork is an acknowledged write (the 0.8.2
///   backend can answer that way), never a failure;
/// * every other status is a failed write, typed by its status, and a failed
///   write is never turned into success by re-reading the old record.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const id = 'artwork-1';
  late List<http.Request> requests;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
    requests = <http.Request>[];
  });

  void backend(http.Response Function(http.Request request) handler) {
    BackendApiService().setHttpClient(
      MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  Map<String, Object?> artworkJson(String title) => <String, Object?>{
        'id': id,
        'walletAddress': '0xabc',
        'title': title,
        'artist': 'Artist',
        'description': 'd',
        'latitude': 46.05,
        'longitude': 14.5,
        'rewards': 0,
        'createdAt': '2026-01-01T00:00:00.000Z',
      };

  http.Response json(int status, Object body) => http.Response(
        jsonEncode(body),
        status,
        headers: const {'content-type': 'application/json'},
      );

  Artwork seeded() => Artwork(
        id: id,
        walletAddress: '0xabc',
        title: 'Original title',
        artist: 'Artist',
        description: 'd',
        position: const LatLng(46.05, 14.5),
        rewards: 0,
        createdAt: DateTime(2026, 1, 1),
      );

  ArtworkProvider provider() => ArtworkProvider(backendApi: BackendApiService())
    ..addOrUpdateArtwork(seeded());

  group('BackendApiService.updateArtwork', () {
    test('200 with an artwork payload returns the artwork', () async {
      backend((r) => r.method == 'PUT'
          ? json(200, {
              'success': true,
              'data': {'artwork': artworkJson('New title')},
            })
          : json(500, {}));

      final updated =
          await BackendApiService().updateArtwork(id, {'title': 'New title'});

      expect(updated?.title, 'New title');
      expect(requests.where((r) => r.method == 'PUT'), hasLength(1));
    });

    test('200 acknowledgement without an artwork, read-back failing, is null',
        () async {
      backend((r) =>
          r.method == 'PUT' ? json(200, {'success': true}) : json(500, {}));

      final updated =
          await BackendApiService().updateArtwork(id, {'title': 'New title'});

      expect(updated, isNull);
    });

    for (final status in <int>[400, 401, 403, 404, 409, 422, 429, 500, 503]) {
      test('HTTP $status throws a typed request exception, not null', () async {
        backend((r) => json(status, {'success': false, 'error': 'nope'}));

        await expectLater(
          BackendApiService().updateArtwork(id, {'title': 'New title'}),
          throwsA(
            isA<BackendApiRequestException>()
                .having((e) => e.statusCode, 'statusCode', status),
          ),
        );
      });
    }

    test('a transport timeout throws a typed 504', () async {
      backend((r) => throw TimeoutException('slow'));

      await expectLater(
        BackendApiService().updateArtwork(id, {'title': 'New title'}),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', 504),
        ),
      );
    });
  });

  group('ArtworkProvider.saveArtwork', () {
    test('confirmed: the cache holds the server record', () async {
      backend((r) => json(200, {
            'success': true,
            'data': {'artwork': artworkJson('New title')},
          }));
      final artworks = provider();

      final result = await artworks.saveArtwork(id, {'title': 'New title'});

      expect(result.status, ArtworkUpdateStatus.confirmed);
      expect(result.succeeded, isTrue);
      expect(artworks.getArtworkById(id)?.title, 'New title');
    });

    test('acknowledged: success, with the edits applied to the cache',
        () async {
      backend((r) =>
          r.method == 'PUT' ? json(200, {'success': true}) : json(500, {}));
      final artworks = provider();

      final result = await artworks.saveArtwork(id, {'title': 'New title'});

      expect(result.status, ArtworkUpdateStatus.acknowledged);
      expect(result.succeeded, isTrue);
      expect(artworks.getArtworkById(id)?.title, 'New title');
    });

    final expectations = <int, ArtworkUpdateFailure>{
      400: ArtworkUpdateFailure.rejected,
      401: ArtworkUpdateFailure.unauthorized,
      403: ArtworkUpdateFailure.forbidden,
      409: ArtworkUpdateFailure.conflict,
      429: ArtworkUpdateFailure.rateLimited,
      500: ArtworkUpdateFailure.server,
      504: ArtworkUpdateFailure.timeout,
    };
    for (final entry in expectations.entries) {
      test(
          'HTTP ${entry.key} is a failure (${entry.value.name}); the old '
          'record stays and is never read back as a save', () async {
        // The old record is readable. A save that falls back to a read would
        // report success here, which is the bug this contract removes.
        backend((r) => r.method == 'PUT'
            ? json(entry.key, {'success': false})
            : json(200, {
                'success': true,
                'data': {'artwork': artworkJson('Original title')},
              }));
        final artworks = provider();

        final result = await artworks.saveArtwork(id, {'title': 'New title'});

        expect(result.status, ArtworkUpdateStatus.failed);
        expect(result.succeeded, isFalse);
        expect(result.failure, entry.value);
        expect(requests.where((r) => r.method == 'GET'), isEmpty);
        expect(artworks.getArtworkById(id)?.title, 'Original title');
      });
    }

    test('a second save while one is in flight is refused, not sent', () async {
      final gate = Completer<http.Response>();
      backend((r) => throw StateError('use the async handler'));
      BackendApiService().setHttpClient(
        MockClient((request) {
          requests.add(request);
          return gate.future;
        }),
      );
      final artworks = provider();

      final first = artworks.saveArtwork(id, {'title': 'New title'});
      await Future<void>.delayed(Duration.zero);
      final second = await artworks.saveArtwork(id, {'title': 'Another'});

      expect(second.status, ArtworkUpdateStatus.alreadyInFlight);
      expect(second.succeeded, isFalse);

      gate.complete(json(200, {
        'success': true,
        'data': {'artwork': artworkJson('New title')},
      }));
      expect((await first).status, ArtworkUpdateStatus.confirmed);
      expect(requests.where((r) => r.method == 'PUT'), hasLength(1));
    });

    test('the legacy updateArtwork returns null on failure, artwork on success',
        () async {
      backend((r) => json(409, {'success': false}));
      expect(await provider().updateArtwork(id, {'title': 'x'}), isNull);

      backend((r) => json(200, {
            'success': true,
            'data': {'artwork': artworkJson('New title')},
          }));
      expect(
        (await provider().updateArtwork(id, {'title': 'New title'}))?.title,
        'New title',
      );
    });
  });
}
