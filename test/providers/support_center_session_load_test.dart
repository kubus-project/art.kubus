import 'dart:convert';

import 'package:art_kubus/providers/support_center_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shape-only session token; the backend is faked, so only presence matters.
const _authToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

/// Answers at once with nothing stored in secure storage (see the screen test).
const _secureStorage =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

BackendApiService get api => BackendApiService();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async => null);
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
    api.setHttpClient(createPlatformHttpClient());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
  });

  test('loadTickets reads the stored session before deciding who is asking',
      () async {
    // Cold start: the token is only in storage, not yet in memory.
    api.setAuthTokenForTesting(null);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _authToken,
    });
    final calls = <http.Request>[];
    api.setHttpClient(MockClient((request) async {
      calls.add(request);
      return http.Response(
        jsonEncode(<String, Object?>{'success': true, 'data': <Object?>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }));

    final support = SupportCenterProvider(supportEnabled: true);
    await support.loadTickets();

    expect(support.listFailure, isNull);
    expect(support.tickets, isEmpty);
    expect(calls, hasLength(1));
    expect(
      calls.single.headers.keys.any((k) => k.toLowerCase() == 'authorization'),
      isTrue,
    );
  });

  test('loadTickets reports the sign-in state for a guest without any request',
      () async {
    api.setAuthTokenForTesting(null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final calls = <http.Request>[];
    api.setHttpClient(MockClient((request) async {
      calls.add(request);
      return http.Response('{}', 200);
    }));

    final support = SupportCenterProvider(supportEnabled: true);
    await support.loadTickets();

    expect(support.listFailure, SupportFailure.signIn);
    expect(support.tickets, isNull);
    expect(calls, isEmpty);
  });
}
