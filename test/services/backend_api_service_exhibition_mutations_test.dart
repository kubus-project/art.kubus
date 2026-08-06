import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/models/exhibition.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _createPath = '/api/exhibitions';
const _exhibitionId = 'exh-contract-1';
const _updatePath = '/api/exhibitions/$_exhibitionId';

Map<String, Object?> _exhibitionJson({String id = _exhibitionId}) {
  return <String, Object?>{
    'id': id,
    'title': 'Contract exhibition',
    'description': 'Contract description',
    'status': 'draft',
  };
}

http.Response _jsonResponse(Object? body, int statusCode) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting('token');
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
    BackendApiService().setAuthTokenForTesting(null);
  });

  Future<void> expectCreateThrows({
    required Future<http.Response> Function(http.Request request) handler,
    required Matcher matcher,
  }) async {
    BackendApiService().setHttpClient(MockClient(handler));
    await expectLater(
      BackendApiService().createExhibition(<String, dynamic>{
        'title': 'Contract exhibition',
      }),
      throwsA(matcher),
    );
  }

  Future<void> expectUpdateThrows({
    required Future<http.Response> Function(http.Request request) handler,
    required Matcher matcher,
  }) async {
    BackendApiService().setHttpClient(MockClient(handler));
    await expectLater(
      BackendApiService().updateExhibition(
        _exhibitionId,
        <String, dynamic>{'status': 'published'},
      ),
      throwsA(matcher),
    );
  }

  group('createExhibition', () {
    test('returns the parsed exhibition for a successful response', () async {
      late Map<String, dynamic> requestBody;
      BackendApiService().setHttpClient(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, _createPath);
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse(
            <String, Object?>{'success': true, 'data': _exhibitionJson()},
            201,
          );
        }),
      );

      final exhibition = await BackendApiService().createExhibition(
        <String, dynamic>{'title': 'Contract exhibition'},
      );

      expect(exhibition, isA<Exhibition>());
      expect(exhibition!.id, _exhibitionId);
      expect(exhibition.title, 'Contract exhibition');
      expect(requestBody['title'], 'Contract exhibition');
    });

    test('throws BackendApiRequestException on non-2xx', () async {
      await expectCreateThrows(
        handler: (request) async => _jsonResponse(
          <String, Object?>{'success': false, 'error': 'validation failed'},
          422,
        ),
        matcher: isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 422)
            .having((error) => error.path, 'path', _createPath)
            .having(
                (error) => error.body, 'body', contains('validation failed')),
      );
    });

    test('throws instead of reporting an id-less exhibition as created',
        () async {
      await expectCreateThrows(
        handler: (request) async =>
            _jsonResponse(<String, Object?>{'success': true}, 201),
        matcher: isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 201)
            .having((error) => error.path, 'path', _createPath),
      );
    });

    test('throws when a 2xx body carries an empty exhibition id', () async {
      await expectCreateThrows(
        handler: (request) async => _jsonResponse(
          <String, Object?>{
            'success': true,
            'data': <String, Object?>{'id': '   ', 'title': 'Ghost'},
          },
          201,
        ),
        matcher: isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 201)
            .having((error) => error.path, 'path', _createPath),
      );
    });

    test('maps timeouts to BackendApiRequestException 504', () async {
      await expectCreateThrows(
        handler: (request) async => throw TimeoutException('slow create'),
        matcher: isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 504)
            .having((error) => error.path, 'path', _createPath)
            .having((error) => error.body, 'body', 'slow create'),
      );
    });

    test('maps client transport errors to status 0', () async {
      await expectCreateThrows(
        handler: (request) async => throw http.ClientException('socket closed'),
        matcher: isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 0)
            .having((error) => error.path, 'path', _createPath)
            .having((error) => error.body, 'body', 'socket closed'),
      );
    });
  });

  group('updateExhibition', () {
    test('returns the parsed exhibition for a successful response', () async {
      BackendApiService().setHttpClient(
        MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, _updatePath);
          return _jsonResponse(
            <String, Object?>{
              'success': true,
              'data': _exhibitionJson()..['status'] = 'published',
            },
            200,
          );
        }),
      );

      final exhibition = await BackendApiService().updateExhibition(
        _exhibitionId,
        <String, dynamic>{'status': 'published'},
      );

      expect(exhibition, isA<Exhibition>());
      expect(exhibition!.id, _exhibitionId);
      expect(exhibition.status, 'published');
    });

    test('throws BackendApiRequestException on non-2xx', () async {
      await expectUpdateThrows(
        handler: (request) async => _jsonResponse(
          <String, Object?>{'success': false, 'error': 'server exploded'},
          500,
        ),
        matcher: isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 500)
            .having((error) => error.path, 'path', _updatePath)
            .having((error) => error.body, 'body', contains('server exploded')),
      );
    });

    test('throws on an unparseable 2xx instead of re-reading', () async {
      // `getExhibition` is an unauthenticated public read with a snapshot
      // fallback, so it can return a stale or pre-update record. It must never
      // be used to confirm that a write landed.
      var getCalls = 0;
      BackendApiService().setHttpClient(
        MockClient((request) async {
          if (request.method == 'PUT') {
            return _jsonResponse(<String, Object?>{'success': true}, 200);
          }
          getCalls += 1;
          return _jsonResponse(
            <String, Object?>{
              'success': true,
              'data': _exhibitionJson()..['status'] = 'draft',
            },
            200,
          );
        }),
      );

      await expectLater(
        BackendApiService().updateExhibition(
          _exhibitionId,
          <String, dynamic>{'status': 'published'},
        ),
        throwsA(isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 200)
            .having((error) => error.path, 'path', _updatePath)),
      );
      expect(getCalls, 0);
    });

    test('throws when a 2xx body carries an empty exhibition id', () async {
      await expectUpdateThrows(
        handler: (request) async => _jsonResponse(
          <String, Object?>{
            'success': true,
            'data': <String, Object?>{'id': '  ', 'title': 'Ghost'},
          },
          200,
        ),
        matcher: isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 200)
            .having((error) => error.path, 'path', _updatePath),
      );
    });

    test('maps timeouts to BackendApiRequestException 504', () async {
      await expectUpdateThrows(
        handler: (request) async => throw TimeoutException('slow update'),
        matcher: isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 504)
            .having((error) => error.path, 'path', _updatePath)
            .having((error) => error.body, 'body', 'slow update'),
      );
    });

    test('maps client transport errors to status 0', () async {
      await expectUpdateThrows(
        handler: (request) async => throw http.ClientException('socket closed'),
        matcher: isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 0)
            .having((error) => error.path, 'path', _updatePath)
            .having((error) => error.body, 'body', 'socket closed'),
      );
    });
  });
}
