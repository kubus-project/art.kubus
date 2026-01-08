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

  test('getProfileByWallet does not auto-issue auth for viewed wallet', () async {
    final requests = <http.Request>[];

    final api = BackendApiService();
    api.setHttpClient(MockClient((request) async {
      requests.add(request);

      // Return a minimal successful profile payload.
      return http.Response(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{
            'walletAddress': 'someone_else_wallet',
            'username': 'someone',
            'displayName': 'Someone Else',
          },
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    await api.getProfileByWallet('someone_else_wallet');

    // The critical behavior: viewing a profile must not trigger auth issuance
    // (no POSTs to register/issue-token, no extra calls beyond the profile fetch).
    expect(requests, isNotEmpty);
    expect(requests.every((r) => r.method.toUpperCase() == 'GET'), isTrue);
    expect(
      requests.every((r) => r.url.path.contains('/api/profiles/')),
      isTrue,
      reason: 'Expected only profile fetch requests when viewing a profile.',
    );
  });
}
