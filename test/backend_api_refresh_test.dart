import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _encodeSegment(Map<String, dynamic> payload) {
  final raw = utf8.encode(jsonEncode(payload));
  return base64Url.encode(raw).replaceAll('=', '');
}

String _buildJwt({required int expSeconds}) {
  final header =
      _encodeSegment(<String, dynamic>{'alg': 'HS256', 'typ': 'JWT'});
  final body = _encodeSegment(<String, dynamic>{'exp': expSeconds});
  return '$header.$body.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('refreshAuthTokenFromStorage is a non-transport compatibility shim',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'refresh_token': 'refresh-123',
    });
    var networkCalls = 0;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        networkCalls += 1;
        return http.Response('Not Found', 404);
      }),
    );

    final ok = await BackendApiService().refreshAuthTokenFromStorage();

    expect(ok, isFalse);
    expect(networkCalls, 0);
    expect(BackendApiService().getAuthToken(), isNull);
  });

  test('restoreExistingSession does not call missing refresh route', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _buildJwt(
        expSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600,
      ),
      'refresh_token': 'refresh-123',
    });
    var networkCalls = 0;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        networkCalls += 1;
        return http.Response('Not Found', 404);
      }),
    );

    final ok = await BackendApiService().restoreExistingSession();

    expect(ok, isFalse);
    expect(networkCalls, 0);
    expect(BackendApiService().getAuthToken(), isNull);
  });

  test('registerWallet bootstraps account without restoring session', () async {
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    final bootstrapToken = _buildJwt(expSeconds: exp);

    BackendApiService().setHttpClient(
      MockClient((request) async {
        expect(request.url.path, '/api/auth/register');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'token': bootstrapToken,
              'authProvider': 'wallet_bootstrap',
              'user': {'walletAddress': 'wallet_me'},
            },
          }),
          201,
        );
      }),
    );

    final result = await BackendApiService().registerWallet(
      walletAddress: 'wallet_me',
    );

    expect(result['success'], isTrue);
    expect(BackendApiService().getAuthToken(), isNull);
  });

  test(
      'authenticated GET does not refresh or issue session for expired token',
      () async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiredToken = _buildJwt(expSeconds: nowSeconds - 3600);
    final requestPaths = <String>[];

    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': expiredToken,
      'refresh_token': 'refresh-abc',
    });

    BackendApiService().setHttpClient(
      MockClient((request) async {
        requestPaths.add(request.url.path);
        if (request.url.path.endsWith('/api/profiles/me')) {
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response('Unauthorized', 401);
        }
        return http.Response('Not Found', 404);
      }),
    );

    final result = await BackendApiService().getMyProfile();

    expect(result['success'], isFalse);
    expect(requestPaths, equals(<String>['/api/profiles/me']));
  });
}
