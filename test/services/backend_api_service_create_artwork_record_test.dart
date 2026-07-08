import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wallet = 'WalletCreateArtwork1111111111111111111111111111';

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
      BackendApiService().createArtworkRecord(
        title: 'Created',
        description: 'Created description',
        imageUrl: '/uploads/artworks/cover.png',
        walletAddress: _wallet,
      ),
      throwsA(matcher),
    );
  }

  test('createArtworkRecord returns parsed artwork for successful responses',
      () async {
    late Map<String, dynamic> requestBody;
    BackendApiService().setHttpClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/artworks');
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'art-created-1',
              'title': 'Created',
              'description': 'Created description',
              'imageUrl': '/uploads/artworks/cover.png',
              'walletAddress': _wallet,
              'artistName': 'Creator',
              'category': 'Digital Art',
            },
          }),
          201,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final artwork = await BackendApiService().createArtworkRecord(
      title: 'Created',
      description: 'Created description',
      imageUrl: '/uploads/artworks/cover.png',
      walletAddress: _wallet,
      category: 'Digital Art',
      tags: const <String>['launch'],
    );

    expect(artwork, isNotNull);
    expect(artwork!.id, 'art-created-1');
    expect(artwork.title, 'Created');
    expect(requestBody['walletAddress'], _wallet);
    expect(requestBody['tags'], <String>['launch']);
  });

  test('createArtworkRecord throws BackendApiRequestException on non-2xx',
      () async {
    await expectCreateThrows(
      handler: (request) async => http.Response(
        jsonEncode(<String, Object?>{
          'success': false,
          'error': 'validation failed',
        }),
        422,
        headers: const <String, String>{'content-type': 'application/json'},
      ),
      matcher: isA<BackendApiRequestException>()
          .having((error) => error.statusCode, 'statusCode', 422)
          .having((error) => error.path, 'path', '/api/artworks')
          .having((error) => error.body, 'body', contains('validation failed')),
    );
  });

  test('createArtworkRecord throws BackendApiRequestException on malformed 2xx',
      () async {
    await expectCreateThrows(
      handler: (request) async => http.Response(
        jsonEncode(<String, Object?>{'success': true}),
        201,
        headers: const <String, String>{'content-type': 'application/json'},
      ),
      matcher: isA<BackendApiRequestException>()
          .having((error) => error.statusCode, 'statusCode', 201)
          .having((error) => error.path, 'path', '/api/artworks')
          .having((error) => error.body, 'body', contains('success')),
    );
  });

  test('createArtworkRecord maps timeouts to BackendApiRequestException 504',
      () async {
    await expectCreateThrows(
      handler: (request) async => throw TimeoutException('slow create'),
      matcher: isA<BackendApiRequestException>()
          .having((error) => error.statusCode, 'statusCode', 504)
          .having((error) => error.path, 'path', '/api/artworks')
          .having((error) => error.body, 'body', 'slow create'),
    );
  });

  test('createArtworkRecord maps client transport errors to status 0',
      () async {
    await expectCreateThrows(
      handler: (request) async => throw http.ClientException('socket closed'),
      matcher: isA<BackendApiRequestException>()
          .having((error) => error.statusCode, 'statusCode', 0)
          .having((error) => error.path, 'path', '/api/artworks')
          .having((error) => error.body, 'body', 'socket closed'),
    );
  });
}
