import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService();
    api.setAuthTokenForTesting('account-jwt');
  });

  tearDown(() => api.setAuthTokenForTesting(null));

  test('a setup code is resolved with the account credential', () async {
    api.setHttpClient(MockClient((request) async {
      expect(request.url.path,
          '/api/availability/account/node-installations/by-code/ABCD2345');
      expect(request.headers['Authorization'], 'Bearer account-jwt');
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'installationId': 'install-1',
              'kind': 'NODE_SETUP',
              'fingerprint': 'a' * 64,
              'label': 'Studio',
            }
          }),
          200);
    }));
    final found = await api.getNodeInstallationByCode('ABCD2345');
    expect(found['installationId'], 'install-1');
    expect(found['fingerprint'], 'a' * 64);
  });

  test('authorizing posts to the account-scoped authorize route', () async {
    api.setHttpClient(MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path,
          '/api/availability/account/node-installations/install-1/authorize');
      expect(request.headers['Authorization'], 'Bearer account-jwt');
      // The decision carries no credential material of its own.
      expect(jsonDecode(request.body), isEmpty);
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {'state': 'AUTHORIZED'}
          }),
          200);
    }));
    final result = await api.authorizeNodeInstallation('install-1');
    expect(result['state'], 'AUTHORIZED');
  });

  test('declining posts to the decline route', () async {
    api.setHttpClient(MockClient((request) async {
      expect(request.url.path,
          '/api/availability/account/node-installations/install-1/decline');
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {'state': 'DECLINED'}
          }),
          200);
    }));
    expect((await api.declineNodeInstallation('install-1'))['state'],
        'DECLINED');
  });

  test('a rejected authorization surfaces rather than reading as success',
      () async {
    api.setHttpClient(MockClient((request) async => http.Response('{}', 403)));
    await expectLater(
        api.authorizeNodeInstallation('install-1'), throwsA(anything));
  });
}
