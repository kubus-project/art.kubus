import 'dart:async';
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

  group('data is scoped to the signed-in account', () {
    String jwt(String id, {String signature = 'sig'}) {
      String part(Map<String, Object?> value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      return '${part(<String, Object?>{'alg': 'HS256'})}.'
          '${part(<String, Object?>{'id': id, 'exp': 4733856000})}.$signature';
    }

    http.Response ok(Object? data) => http.Response(
          jsonEncode(<String, Object?>{'success': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );

    Map<String, Object?> ticket(String id, String subject) =>
        <String, Object?>{'id': id, 'subject': subject, 'status': 'open'};

    test('logout and an account switch clear the previous account at once',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      api.setAuthTokenForTesting(jwt('account-a'));
      final tokenA = jwt('account-a');
      api.setHttpClient(MockClient((request) async {
        final auth = request.headers['Authorization'] ?? '';
        return ok(auth.contains(tokenA.split('.')[1])
            ? <Object?>[ticket('t-a', 'A private subject')]
            : <Object?>[ticket('t-b', 'B subject')]);
      }));

      final support = SupportCenterProvider(supportEnabled: true);
      await support.loadTickets();
      expect(support.tickets?.single['subject'], 'A private subject');

      // Logout: nothing of account A remains visible, before any new request.
      api.setAuthTokenForTesting(null);
      expect(support.tickets, isNull);
      expect(support.openId, isNull);
      expect(support.ticket, isNull);

      // Another account opens Support Center: it never sees A's requests.
      api.setAuthTokenForTesting(jwt('account-b'));
      expect(support.tickets, isNull);
      await support.loadTickets();
      expect(support.tickets?.single['subject'], 'B subject');
      expect(support.openId, isNull);
    });

    test('a response that returns after the account changed is dropped',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      api.setAuthTokenForTesting(jwt('account-a'));
      final late = Completer<http.Response>();
      var calls = 0;
      api.setHttpClient(MockClient((request) async {
        calls += 1;
        if (calls == 1) return late.future;
        return ok(<Object?>[ticket('t-b', 'B subject')]);
      }));

      final support = SupportCenterProvider(supportEnabled: true);
      final first = support.loadTickets();
      await Future<void>.delayed(Duration.zero);

      api.setAuthTokenForTesting(jwt('account-b'));
      await support.loadTickets();
      expect(support.tickets?.single['subject'], 'B subject');

      // A's slow response finally arrives and must not replace B's list.
      late.complete(ok(<Object?>[ticket('t-a', 'A private subject')]));
      await first;
      expect(support.tickets?.single['subject'], 'B subject');
      expect(support.listLoading, isFalse);
    });

    test('a refreshed token for the same account keeps its data', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      api.setAuthTokenForTesting(jwt('account-a', signature: 'first'));
      api.setHttpClient(MockClient(
        (request) async => ok(<Object?>[ticket('t-a', 'A subject')]),
      ));
      final support = SupportCenterProvider(supportEnabled: true);
      await support.loadTickets();

      api.setAuthTokenForTesting(jwt('account-a', signature: 'second'));
      expect(support.tickets?.single['subject'], 'A subject');
    });
  });
}
