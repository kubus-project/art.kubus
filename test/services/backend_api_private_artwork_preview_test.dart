import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _id = '11111111-1111-4111-8111-111111111111';
const _path = '/api/artworks/$_id/media/cover';

Map<String, dynamic> _draftJson() => <String, dynamic>{
      'id': _id,
      'title': 'Draft',
      'artist': '',
      'description': '',
      'latitude': 46.0,
      'longitude': 14.0,
      'isPublic': false,
      'mediaPreview': <String, dynamic>{
        'auth': 'bearer',
        'cover': _path,
        'gallery': <String?>['/api/artworks/$_id/media/gallery-0'],
        'poap': null,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService();
    api.setAuthTokenForTesting('preview-test-token');
  });

  tearDown(() {
    api.setHttpClient(http.Client());
    api.setAuthTokenForTesting(null);
  });

  test(
    'authenticated owner detail parses a nullable private descriptor',
    () async {
      api.setHttpClient(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/artworks/$_id');
          expect(request.headers['authorization'], 'Bearer preview-test-token');
          return http.Response(
            jsonEncode(<String, Object?>{'data': _draftJson()}),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final artwork = await api.getArtworkDetailWithMediaPreview(_id);
      expect(artwork.isPublic, isFalse);
      expect(artwork.mediaPreview?.auth, 'bearer');
      expect(artwork.mediaPreview?.pathFor('cover'), _path);
      expect(artwork.toMap().containsKey('mediaPreview'), isFalse);
    },
  );

  test('current media detail is a bounded direct current-row request',
      () async {
    final requests = <http.Request>[];
    api.setHttpClient(
      MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.url.path, '/api/artworks/$_id');
        expect(request.url.queryParameters,
            <String, String>{'currentMedia': 'true'});
        expect(request.followRedirects, isFalse);
        expect(request.headers['authorization'], 'Bearer preview-test-token');
        expect(request.headers['cache-control'], 'no-cache, no-store');
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'source': 'postgresql',
            'mode': 'current-media',
            'current': true,
            'publicMediaAllowed': true,
            'data': _draftJson()
              ..['isPublic'] = true
              ..['isActive'] = true
              ..['editorialState'] = 'approved',
          }),
          200,
          headers: const <String, String>{
            'content-type': 'application/json',
            'cache-control': 'private, no-cache, no-store',
          },
        );
      }),
    );

    final result = await api.getArtworkCurrentMediaDetail(
      _id,
      includeAuth: true,
    );
    expect(result.publicMediaAllowed, isTrue);
    expect(result.artwork.id, _id);
    expect(result.artwork.canUsePublicMedia, isTrue);
    expect(requests, hasLength(1));

    api.setHttpClient(MockClient((request) async => http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'source': 'postgresql',
            'mode': 'current-media',
            'current': true,
            'publicMediaAllowed': false,
            'data': _draftJson()
              ..['isPublic'] = true
              ..['isActive'] = true
              ..['editorialState'] = 'approved',
          }),
          200,
          headers: const <String, String>{
            'cache-control': 'private, no-cache, no-store',
          },
        )));
    final heldOwner = await api.getArtworkCurrentMediaDetail(
      _id,
      includeAuth: true,
    );
    expect(heldOwner.publicMediaAllowed, isFalse);
    expect(heldOwner.artwork.isPublic, isTrue);
    expect(heldOwner.artwork.canUsePublicMedia, isFalse);
    expect(heldOwner.artwork.toMap().containsKey('currentPublicMediaAllowed'),
        isFalse);
  });

  test('mint current detail binds to canonical UUID and rejects wrong aliases',
      () async {
    const mint = 'MintAddress111111111111111111111111111111';
    final payload = <String, Object?>{
      'success': true,
      'source': 'postgresql',
      'mode': 'current-media',
      'current': true,
      'publicMediaAllowed': true,
      'data': _draftJson()
        ..['id'] = _id
        ..['isNft'] = true
        ..['nftMintAddress'] = mint
        ..['isPublic'] = true
        ..['isActive'] = true
        ..['editorialState'] = 'approved',
    };
    api.setHttpClient(MockClient((request) async {
      expect(request.url.path, '/api/artworks/$mint');
      expect(request.url.queryParameters['currentMedia'], 'true');
      return http.Response(
        jsonEncode(payload),
        200,
        headers: const <String, String>{
          'cache-control': 'private, no-cache, no-store',
        },
      );
    }));
    final result = await api.getArtworkCurrentMediaDetail(
      mint,
      includeAuth: false,
    );
    expect(result.artwork.id, _id);
    expect(result.artwork.nftMintAddress, mint);

    api.setHttpClient(MockClient((request) async => http.Response(
          jsonEncode(payload),
          200,
          headers: const <String, String>{
            'cache-control': 'private, no-cache, no-store',
          },
        )));
    payload['data'] = <String, Object?>{
      ..._draftJson(),
      'id': _id,
      'isNft': true,
      'nftMintAddress': 'some-other-mint',
    };
    await expectLater(
      api.getArtworkCurrentMediaDetail(mint, includeAuth: false),
      throwsFormatException,
    );

    payload['data'] = <String, Object?>{
      ..._draftJson(),
      'id': 'not-a-canonical-uuid',
      'isNft': true,
      'nftMintAddress': mint,
    };
    await expectLater(
      api.getArtworkCurrentMediaDetail(mint, includeAuth: false),
      throwsFormatException,
    );
  });

  test(
      'current detail denial, malformed body, redirect, and outage fail closed',
      () async {
    final requests = <http.Request>[];
    api.setHttpClient(
      MockClient((request) async {
        requests.add(request);
        return http.Response('{"error":"offline"}', 503);
      }),
    );
    await expectLater(
      api.getArtworkCurrentMediaDetail(_id, includeAuth: false),
      throwsA(isA<BackendApiRequestException>().having(
        (error) => error.statusCode,
        'statusCode',
        503,
      )),
    );
    expect(requests, hasLength(1));

    api.setHttpClient(MockClient((request) async => http.Response(
          '{"success":true,"source":"postgresql","mode":"wrong-mode","current":true,"publicMediaAllowed":true,"data":{"id":"$_id"}}',
          200,
          headers: const <String, String>{
            'cache-control': 'private, no-cache, no-store',
          },
        )));
    await expectLater(
      api.getArtworkCurrentMediaDetail(_id, includeAuth: false),
      throwsFormatException,
    );

    api.setHttpClient(MockClient((request) async => http.Response(
          'redirect',
          302,
          headers: const <String, String>{
            'location': 'https://evil.test/steal'
          },
        )));
    await expectLater(
      api.getArtworkCurrentMediaDetail(_id, includeAuth: true),
      throwsA(isA<BackendApiRequestException>()),
    );
  });

  test('current detail response body is bounded while streamed', () async {
    api.setHttpClient(MockClient((request) async => http.Response(
          List<String>.filled(1024 * 1024 + 1, 'x').join(),
          200,
          headers: const <String, String>{
            'cache-control': 'private, no-cache, no-store',
          },
        )));
    await expectLater(
      api.getArtworkCurrentMediaDetail(_id, includeAuth: false),
      throwsFormatException,
    );
  });

  test(
    'private byte transport sends bearer only to the descriptor-bound path',
    () async {
      api.setHttpClient(
        MockClient((request) async {
          expect(request.url.path, _path);
          expect(request.headers['authorization'], 'Bearer preview-test-token');
          return http.Response.bytes(
            <int>[1, 2, 3],
            200,
            headers: const <String, String>{
              'content-type': 'image/png',
              'cache-control': 'private, no-cache, no-store',
            },
          );
        }),
      );

      expect(
        await api.getArtworkPrivateMediaBytes(
          artworkId: _id,
          slot: 'cover',
          descriptorPath: _path,
        ),
        <int>[1, 2, 3],
      );
      await expectLater(
        api.getArtworkPrivateMediaBytes(
          artworkId: _id,
          slot: 'cover',
          descriptorPath: '/api/artworks/another/media/cover',
        ),
        throwsFormatException,
      );
    },
  );

  test('an account switch rejects private bytes that complete late', () async {
    final responseCompleter = Completer<http.Response>();
    api.setHttpClient(
      MockClient((request) {
        expect(request.headers['authorization'], 'Bearer preview-test-token');
        return responseCompleter.future;
      }),
    );

    final pending = api.getArtworkPrivateMediaBytes(
      artworkId: _id,
      slot: 'cover',
      descriptorPath: _path,
    );
    await Future<void>.delayed(Duration.zero);
    api.setAuthTokenForTesting('another-account-token');
    responseCompleter.complete(
      http.Response.bytes(
        <int>[1, 2, 3],
        200,
        headers: const <String, String>{
          'content-type': 'image/png',
          'cache-control': 'private, no-cache, no-store',
        },
      ),
    );

    await expectLater(pending, throwsStateError);
  });

  group('bounded private media stream', () {
    Future<List<int>> read() => api.getArtworkPrivateMediaBytes(
          artworkId: _id,
          slot: 'cover',
          descriptorPath: _path,
        );

    test(
      'a valid small image streams through the bounded transport',
      () async {
        final probe = _BodyProbe();
        final fake = _StreamingFakeClient(
          _serve(
              probe,
              <Object>[
                <int>[1, 2, 3],
              ],
              contentLength: 3),
        );
        api.setHttpClient(fake);

        final bytes = await read();
        expect(bytes, <int>[1, 2, 3]);
        expect(bytes, isA<Uint8List>());
        expect(fake.sent, hasLength(1));
        final sent = fake.sent.single;
        expect(sent.method, 'GET');
        expect(sent.url.path, _path);
        expect(sent.url.query, isEmpty);
        expect(sent.url.toString(), isNot(contains('preview-test-token')));
        expect(sent.headers['authorization'], 'Bearer preview-test-token');
        expect(probe.finalized, isTrue);
      },
    );

    test('a small body without a declared length is accepted', () async {
      final probe = _BodyProbe();
      api.setHttpClient(
        _StreamingFakeClient(
          _serve(
              probe,
              <Object>[
                <int>[7, 8],
              ],
              contentLength: null),
        ),
      );

      expect(await read(), <int>[7, 8]);
    });

    test(
      'a declared length above the cap is refused before the body is read',
      () async {
        final probe = _BodyProbe();
        api.setHttpClient(
          _StreamingFakeClient(
            _serve(probe, const <Object>[], contentLength: _cap + 1),
          ),
        );

        await expectLater(read(), throwsFormatException);
        expect(probe.started, isFalse);
        expect(probe.chunksProduced, 0);
      },
    );

    test(
      'a missing content length with an oversized body is cancelled at the cap',
      () async {
        final probe = _BodyProbe();
        api.setHttpClient(
          _StreamingFakeClient(
            _serve(probe, _oversizedChunks(), contentLength: null),
          ),
        );

        await expectLater(read(), throwsFormatException);
        await _settle();
        expect(probe.chunksProduced, lessThanOrEqualTo(_cap ~/ _mib + 1));
        expect(probe.bytesProduced, lessThanOrEqualTo(_cap + _mib));
        expect(probe.finalized, isTrue);
      },
    );

    test(
      'a misleading small content length with an oversized body is cancelled at the cap',
      () async {
        final probe = _BodyProbe();
        api.setHttpClient(
          _StreamingFakeClient(
            _serve(probe, _oversizedChunks(), contentLength: 10),
          ),
        );

        await expectLater(read(), throwsFormatException);
        await _settle();
        expect(probe.chunksProduced, lessThanOrEqualTo(_cap ~/ _mib + 1));
        expect(probe.bytesProduced, lessThanOrEqualTo(_cap + _mib));
        expect(probe.finalized, isTrue);
      },
    );

    test(
      'a chunk that crosses the cap is dropped and the body is cancelled',
      () async {
        final probe = _BodyProbe();
        api.setHttpClient(
          _StreamingFakeClient(
            _serve(
                probe,
                <Object>[
                  Uint8List(30 * _mib),
                  Uint8List(25 * _mib),
                  Uint8List(_mib),
                ],
                contentLength: null),
          ),
        );

        await expectLater(read(), throwsFormatException);
        await _settle();
        expect(probe.chunksProduced, 2);
        expect(probe.finalized, isTrue);
      },
    );

    test('a body of exactly the cap is accepted', () async {
      final probe = _BodyProbe();
      api.setHttpClient(
        _StreamingFakeClient(
          _serve(
              probe,
              <Object>[
                Uint8List(25 * _mib),
                Uint8List(25 * _mib),
              ],
              contentLength: _cap),
        ),
      );

      expect(await read(), hasLength(_cap));
      expect(probe.finalized, isTrue);
    });

    test(
      'a network error mid-stream surfaces the error and returns no bytes',
      () async {
        final probe = _BodyProbe();
        api.setHttpClient(
          _StreamingFakeClient(
            _serve(
                probe,
                <Object>[
                  <int>[1, 2, 3],
                  http.ClientException('connection reset'),
                  <int>[4, 5, 6],
                ],
                contentLength: null),
          ),
        );

        await expectLater(read(), throwsA(isA<http.ClientException>()));
        await _settle();
        expect(probe.chunksProduced, 1);
        expect(probe.finalized, isTrue);
      },
    );

    test(
      'an account change mid-load drops late chunks and cancels the body',
      () async {
        final probe = _BodyProbe();
        api.setHttpClient(
          _StreamingFakeClient(
            _serve(
                probe,
                <Object>[
                  <int>[1, 2, 3],
                  () => api.setAuthTokenForTesting('another-account-token'),
                  <int>[4, 5, 6],
                  <int>[7, 8, 9],
                ],
                contentLength: null),
          ),
        );

        await expectLater(read(), throwsStateError);
        await _settle();
        // The late chunk was produced, dropped, and nothing after it was pulled.
        expect(probe.chunksProduced, 2);
        expect(probe.finalized, isTrue);
      },
    );

    test(
      'a body that completes after an account switch is rejected',
      () async {
        final probe = _BodyProbe();
        api.setHttpClient(
          _StreamingFakeClient(
            _serve(
                probe,
                <Object>[
                  <int>[1, 2, 3],
                  () => api.setAuthTokenForTesting('another-account-token'),
                ],
                contentLength: 3),
          ),
        );

        await expectLater(read(), throwsStateError);
      },
    );

    test('a failed read is not cached: the next read fetches again', () async {
      var calls = 0;
      final badProbe = _BodyProbe();
      final goodProbe = _BodyProbe();
      api.setHttpClient(
        _StreamingFakeClient((request) async {
          calls += 1;
          if (calls == 1) {
            return _serve(badProbe, const <Object>[], contentLength: _cap + 1)(
              request,
            );
          }
          return _serve(
              goodProbe,
              <Object>[
                <int>[9, 8],
              ],
              contentLength: 2)(request);
        }),
      );

      await expectLater(read(), throwsFormatException);
      expect(await read(), <int>[9, 8]);
      expect(calls, 2);
    });

    test(
      'a content type outside the image allowlist is still rejected',
      () async {
        final probe = _BodyProbe();
        api.setHttpClient(
          _StreamingFakeClient(
            _serve(
                probe,
                <Object>[
                  <int>[1],
                ],
                contentLength: 1,
                contentType: 'text/html'),
          ),
        );

        await expectLater(read(), throwsFormatException);
      },
    );

    test('a cacheable private media response is still rejected', () async {
      final probe = _BodyProbe();
      api.setHttpClient(
        _StreamingFakeClient(
          _serve(
              probe,
              <Object>[
                <int>[1],
              ],
              contentLength: 1,
              cacheControl: 'public, max-age=60'),
        ),
      );

      await expectLater(read(), throwsFormatException);
    });

    test('a non-200 answer keeps the status error', () async {
      final probe = _BodyProbe();
      api.setHttpClient(
        _StreamingFakeClient(
          _serve(probe, const <Object>[], contentLength: 0, status: 404),
        ),
      );

      await expectLater(
        read(),
        throwsA(
          isA<BackendApiRequestException>().having(
            (error) => error.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test(
      'a declared length above the cap releases the body without reading it',
      () async {
        final body = _ObservedBody();
        api.setHttpClient(
          _StreamingFakeClient(
            (_) async => http.StreamedResponse(
              body.stream(_mibChunks(60)),
              200,
              contentLength: _cap + 1,
              headers: const <String, String>{
                'content-type': 'image/png',
                'cache-control': 'private, no-cache, no-store',
              },
            ),
          ),
        );

        await expectLater(read(), throwsFormatException);
        await _settle();
        expect(body.cancelled, isTrue);
        expect(body.chunksProduced, 0);
      },
    );

    test('the bearer-carrying request does not follow a redirect', () async {
      final target = _BodyProbe();
      final fake = _StreamingFakeClient(
        (request) async {
          if (request.url.host == 'elsewhere.example') {
            return _serve(
                target,
                <Object>[
                  <int>[9],
                ],
                contentLength: 1)(request);
          }
          return http.StreamedResponse(
            _scriptedBody(_BodyProbe(), const <Object>[]),
            302,
            contentLength: 0,
            headers: const <String, String>{
              'location': 'https://elsewhere.example$_path',
            },
          );
        },
        followsRedirects: true,
      );
      api.setHttpClient(fake);

      await expectLater(
        read(),
        throwsA(
          isA<BackendApiRequestException>().having(
            (error) => error.statusCode,
            'statusCode',
            302,
          ),
        ),
      );
      expect(fake.sent, hasLength(1));
      expect(fake.sent.single.followRedirects, isFalse);
      expect(target.started, isFalse);
    });

    test(
      'a cancel that fails while an oversized body is dropped surfaces no zone error',
      () async {
        final zoneErrors = <Object>[];
        await runZonedGuarded(
          () async {
            late StreamController<List<int>> body;
            body = StreamController<List<int>>(
              onListen: () => scheduleMicrotask(() {
                body.add(Uint8List(30 * _mib));
                body.add(Uint8List(25 * _mib));
                body.add(Uint8List(_mib));
              }),
              onCancel: () => Future<void>.error(StateError('cancel failed')),
            );
            api.setHttpClient(
              _StreamingFakeClient(
                (_) async => http.StreamedResponse(
                  body.stream,
                  200,
                  contentLength: null,
                  headers: const <String, String>{
                    'content-type': 'image/png',
                    'cache-control': 'private, no-cache, no-store',
                  },
                ),
              ),
            );

            await expectLater(read(), throwsFormatException);
            await _settle();
          },
          (error, stack) => zoneErrors.add(error),
        );
        expect(zoneErrors, isEmpty);
      },
    );

    test(
      'a stalled body times out and its subscription is cancelled',
      () async {
        final body = _ObservedBody();
        api.setHttpClient(
          _StreamingFakeClient(
            (_) async => http.StreamedResponse(
              body.stream(<List<int>>[Uint8List(_mib)], closeAfter: false),
              200,
              contentLength: null,
              headers: const <String, String>{
                'content-type': 'image/png',
                'cache-control': 'private, no-cache, no-store',
              },
            ),
          ),
        );

        await expectLater(read(), throwsA(isA<TimeoutException>()));
        await _settle();
        expect(body.chunksProduced, 1);
        expect(body.cancelled, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}

const int _mib = 1024 * 1024;
const int _cap = 50 * _mib;

/// Fake transport that records every request and answers each one with a
/// caller-supplied streamed response, so tests control headers and chunks.
class _StreamingFakeClient extends http.BaseClient {
  _StreamingFakeClient(this._respond, {this.followsRedirects = false});

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _respond;

  /// When true, a 3xx answer is followed to its Location with the same headers,
  /// as a redirect-following transport does for a request with followRedirects.
  final bool followsRedirects;
  final List<http.BaseRequest> sent = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request);
    final response = await _respond(request);
    final location = response.headers['location'];
    final isRedirect = response.statusCode >= 300 && response.statusCode < 400;
    if (!followsRedirects ||
        !request.followRedirects ||
        !isRedirect ||
        location == null) {
      return response;
    }
    await response.stream.drain<void>();
    return send(
      http.Request('GET', Uri.parse(location))..headers.addAll(request.headers),
    );
  }
}

/// Observes a scripted body: whether anything listened to it, how many chunks
/// were produced for the listener, and whether the body was torn down.
class _BodyProbe {
  bool started = false;
  bool finalized = false;
  int chunksProduced = 0;
  int bytesProduced = 0;
}

/// Observes a controller-backed body: whether a listener attached, how many
/// chunks were produced, and whether the listener cancelled it.
class _ObservedBody {
  bool cancelled = false;
  int chunksProduced = 0;

  Stream<List<int>> stream(
    Iterable<List<int>> chunks, {
    bool closeAfter = true,
  }) {
    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () => scheduleMicrotask(() {
        for (final chunk in chunks) {
          if (cancelled) return;
          chunksProduced += 1;
          controller.add(chunk);
        }
        if (closeAfter && !cancelled) unawaited(controller.close());
      }),
      onCancel: () {
        cancelled = true;
      },
    );
    return controller.stream;
  }
}

Iterable<List<int>> _mibChunks(int count) =>
    Iterable<List<int>>.generate(count, (_) => Uint8List(_mib));

/// A body built from script steps: byte chunks are yielded, errors are thrown,
/// actions run in place (for example an account switch), and futures are awaited.
Stream<List<int>> _scriptedBody(
    _BodyProbe probe, Iterable<Object> script) async* {
  probe.started = true;
  try {
    for (final step in script) {
      if (step is void Function()) {
        step();
      } else if (step is Future<void>) {
        await step;
      } else if (step is http.ClientException) {
        throw step;
      } else {
        final chunk = step as List<int>;
        probe.chunksProduced += 1;
        probe.bytesProduced += chunk.length;
        yield chunk;
      }
    }
  } finally {
    probe.finalized = true;
  }
}

Future<http.StreamedResponse> Function(http.BaseRequest) _serve(
  _BodyProbe probe,
  Iterable<Object> script, {
  required int? contentLength,
  String contentType = 'image/png',
  String cacheControl = 'private, no-cache, no-store',
  int status = 200,
}) {
  return (_) async => http.StreamedResponse(
        _scriptedBody(probe, script),
        status,
        contentLength: contentLength,
        headers: <String, String>{
          'content-type': contentType,
          'cache-control': cacheControl,
        },
      );
}

/// Lazily produced 1 MiB chunks totalling 60 MiB, which is over the cap.
Iterable<Object> _oversizedChunks() =>
    Iterable<Object>.generate(60, (_) => Uint8List(_mib));

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
