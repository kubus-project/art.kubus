import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('getCollections for another wallet does not auto-issue auth', () async {
    final requests = <http.Request>[];

    final api = BackendApiService();
    api.setHttpClient(MockClient((request) async {
      requests.add(request);

      // The only expected call is an unauthenticated GET to /api/collections.
      if (request.method.toUpperCase() == 'GET' && request.url.path.endsWith('/api/collections')) {
        return http.Response(
          jsonEncode(<String, Object?>{'data': <Object?>[]}),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      // Anything else would indicate auth issuance or unexpected side-effects.
      return http.Response(
        jsonEncode(<String, Object?>{'error': 'unexpected request', 'path': request.url.path, 'method': request.method}),
        500,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    await api.getCollections(walletAddress: 'someone_else_wallet', limit: 6);

    expect(requests, isNotEmpty);
    expect(requests.every((r) => r.method.toUpperCase() == 'GET'), isTrue);
    expect(
      requests.every((r) => r.url.path.endsWith('/api/collections')),
      isTrue,
      reason: 'Expected only collections fetch requests when viewing another user\'s collections.',
    );

    // Critical security behavior: no auth header should be attached for other users.
    expect(
      requests.every((r) => !r.headers.keys.any((k) => k.toLowerCase() == 'authorization')),
      isTrue,
      reason: 'Viewing another user\'s collections must not include Authorization nor trigger token issuance.',
    );
  });
}
