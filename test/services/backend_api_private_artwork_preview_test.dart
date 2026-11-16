import 'dart:async';
import 'dart:convert';

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
}
