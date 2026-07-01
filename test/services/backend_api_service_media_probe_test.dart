import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('verifyImageUrl accepts image HEAD responses through API transport',
      () async {
    final methods = <String>[];
    BackendApiService().setHttpClient(
      MockClient((request) async {
        methods.add(request.method);
        expect(request.url.path, '/uploads/avatar.png');
        return http.Response(
          '',
          200,
          headers: <String, String>{'content-type': 'image/png'},
        );
      }),
    );

    final ok = await BackendApiService()
        .verifyImageUrl('https://api.kubus.site/uploads/avatar.png');

    expect(ok, isTrue);
    expect(methods, <String>['HEAD']);
  });

  test('verifyImageUrl falls back to GET when HEAD is unavailable', () async {
    final methods = <String>[];
    BackendApiService().setHttpClient(
      MockClient((request) async {
        methods.add(request.method);
        if (request.method == 'HEAD') {
          return http.Response('', 405);
        }
        return http.Response(
          'image-bytes',
          200,
          headers: <String, String>{'content-type': 'application/octet-stream'},
        );
      }),
    );

    final ok = await BackendApiService()
        .verifyImageUrl('https://api.kubus.site/uploads/avatar.png');

    expect(ok, isTrue);
    expect(methods, <String>['HEAD', 'GET']);
  });

  test('getStorageStats reads storage stats through API transport', () async {
    BackendApiService().setHttpClient(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/storage/stats');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{'bytes': 1024},
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final stats = await BackendApiService().getStorageStats();

    expect(stats['success'], isTrue);
    expect((stats['data'] as Map<String, dynamic>)['bytes'], 1024);
  });
}
