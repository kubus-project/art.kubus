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

  test('Node discovery uses the account endpoint and account credential',
      () async {
    api.setHttpClient(MockClient((request) async {
      expect(request.url.path, '/api/availability/account/nodes');
      expect(request.headers['Authorization'], 'Bearer account-jwt');
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'nodes': [
                {'nodeId': 'home', 'label': 'Home', 'status': 'offline'}
              ]
            }
          }),
          200);
    }));
    final nodes = await api.getMyAvailabilityNodes();
    expect(nodes.single['nodeId'], 'home');
    expect(nodes.single['status'], 'offline');
  });

  test('discovery failure is not an empty owned Node list', () async {
    api.setHttpClient(MockClient((request) async => http.Response('{}', 403)));
    await expectLater(api.getMyAvailabilityNodes(), throwsA(anything));
  });

  test('new token requests defer default scope selection to the backend',
      () async {
    api.setHttpClient(MockClient((request) async {
      expect(request.url.path, '/api/availability/operator-tokens');
      expect(jsonDecode(request.body), isNot(contains('scopes')));
      return http.Response('{"data":{"token":"kubus_node_test"}}', 201);
    }));
    await api.createAvailabilityOperatorToken(
        label: 'Home', walletAddress: 'wallet');
  });
}
