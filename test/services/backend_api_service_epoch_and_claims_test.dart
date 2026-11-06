import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/services.dart';
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

  // Commits persist credentials through secure storage; back it with a map, as
  // the credential race tests do, so a switch can clean up the previous pair.
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secure = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    secure.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          return secure[key];
        case 'write':
          secure[key] = args['value'] as String;
          return null;
        case 'delete':
          secure.remove(key);
          return null;
        case 'containsKey':
          return secure.containsKey(key);
      }
      return null;
    });
    api = BackendApiService();
    api.setAuthTokenForTesting(null);
    api.resetCredentialStoreForTesting();
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
  });

  test(
      'setAuthToken returns the epoch it committed, which a later sign-out '
      'does not move', () async {
    final committed = await api.setAuthToken(_jwtFor('account-a'));
    expect(committed, api.authSessionEpoch);

    // Another account's commit (a switch) advances the live epoch. The value
    // returned by the first commit still names the session it belongs to.
    await api.setAuthToken(_jwtFor('account-b'));
    expect(api.authSessionEpoch, greaterThan(committed));
    expect(committed, isNot(api.authSessionEpoch));
  });

  test('submitInstitutionClaim encodes the institution id as one path segment',
      () async {
    api.setAuthTokenForTesting(_jwtFor('account-a'));
    http.Request? captured;
    api.setHttpClient(MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'success': false, 'error': 'conflict'}),
        409,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    await expectLater(
      api.submitInstitutionClaim(
        institutionId: 'inst/with space',
        message: 'I represent this institution.',
      ),
      throwsA(isA<BackendApiRequestException>()),
    );

    expect(captured, isNotNull);
    expect(
      captured!.url.toString(),
      contains('/api/institutions/inst%2Fwith%20space/claims'),
    );
  });
}
