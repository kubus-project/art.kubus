import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwtFor(String userId) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode(<String, Object?>{
        'id': userId,
        'sub': userId,
        'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
      })))
      .replaceAll('=', '');
  return 'e30.$payload.';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService();
    api.setAuthTokenForTesting(null);
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
  });

  test(
      'deleteMyAccount sends DELETE /api/auth/me with Authorization and no '
      'wallet parameter', () async {
    final token = _jwtFor('user-google-1');
    api.setAuthTokenForTesting(token);

    http.Request? captured;
    api.setHttpClient(MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, Object?>{'success': true}),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    await api.deleteMyAccount();

    expect(captured, isNotNull);
    expect(captured!.method, 'DELETE');
    expect(captured!.url.path, '/api/auth/me');
    expect(captured!.headers['Authorization'], 'Bearer $token');
    expect(captured!.url.queryParameters.containsKey('walletAddress'), isFalse,
        reason: 'account deletion must never select an account by wallet');
    expect(captured!.body, isEmpty);
  });

  test('deleteMyAccount throws without an auth token and sends nothing',
      () async {
    var requests = 0;
    api.setHttpClient(MockClient((request) async {
      requests += 1;
      return http.Response('should not be called', 500);
    }));

    await expectLater(api.deleteMyAccount(), throwsA(isA<Exception>()));
    expect(requests, 0);
  });

  test('deleteMyAccount surfaces backend rejection instead of false success',
      () async {
    api.setAuthTokenForTesting(_jwtFor('user-google-1'));
    api.setHttpClient(MockClient(
      (_) async => http.Response('{"success":false}', 401),
    ));

    await expectLater(
      api.deleteMyAccount(),
      throwsA(isA<BackendApiRequestException>()),
    );
  });

  test('deleteMyAccount clears the local auth token after backend success',
      () async {
    api.setAuthTokenForTesting(_jwtFor('user-google-1'));
    api.setHttpClient(MockClient(
      (_) async => http.Response('{"success":true}', 200),
    ));

    await api.deleteMyAccount();

    expect((api.getAuthToken() ?? '').isEmpty, isTrue);
  });
}
