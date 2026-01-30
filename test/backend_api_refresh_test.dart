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
  final header = _encodeSegment(<String, dynamic>{'alg': 'HS256', 'typ': 'JWT'});
  final body = _encodeSegment(<String, dynamic>{'exp': expSeconds});
  return '$header.$body.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('refreshAuthTokenFromStorage refreshes access token with stored refresh token', () async {
    final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final refreshedToken = _buildJwt(expSeconds: exp);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'refresh_token': 'refresh-123',
    });

    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/refresh')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['refreshToken'], 'refresh-123');
          return http.Response(jsonEncode({'token': refreshedToken}), 200);
        }
        return http.Response('Not Found', 404);
      }),
    );

    final ok = await BackendApiService().refreshAuthTokenFromStorage();

    expect(ok, isTrue);
    expect((BackendApiService().getAuthToken() ?? '').isNotEmpty, isTrue);
  });

  test('refreshAuthTokenFromStorage returns false for invalid refresh token', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'refresh_token': 'refresh-123',
    });

    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/refresh')) {
          return http.Response('Unauthorized', 401);
        }
        return http.Response('Not Found', 404);
      }),
    );

    final ok = await BackendApiService().refreshAuthTokenFromStorage();

    expect(ok, isFalse);
  });
}
