import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:art_kubus/models/account_closure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const receiptId = '00000000-0000-4000-8000-000000000001';
final receiptToken = 'a' * 64;
http.Response preparedReceipt() => http.Response(
    jsonEncode({
      'success': true,
      'closure': {'operationId': receiptId, 'statusToken': receiptToken}
    }),
    200);

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

class FailedReceiptStore extends AuthCredentialStore {
  FailedReceiptStore() : super(web: true);
  @override
  Future<void> saveClosureReceipt(String receipt) async =>
      throw StateError('synthetic storage unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService();
    api.setAuthTokenForTesting(null);
    api.resetCredentialStoreForTesting(store: AuthCredentialStore(web: true));
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
      if (request.url.path.endsWith('/prepare')) return preparedReceipt();
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
      (request) async => request.url.path.endsWith('/prepare')
          ? preparedReceipt()
          : http.Response('{"success":true}', 200),
    ));

    await api.deleteMyAccount();

    expect((api.getAuthToken() ?? '').isEmpty, isTrue);
  });

  test('closure receipt survives logout and status uses its own bearer',
      () async {
    api.setAuthTokenForTesting(_jwtFor('synthetic-user'));
    final requests = <http.Request>[];
    api.setHttpClient(MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/prepare')) return preparedReceipt();
      if (request.method == 'DELETE') {
        return http.Response('{"success":true}', 200);
      }
      return http.Response(
          '{"success":true,"data":{"state":"review_required","lawfulRetention":true}}',
          200);
    }));
    await api.deleteMyAccount();
    expect(requests.map((r) => r.url.path),
        ['/api/auth/account-closure/prepare', '/api/auth/me']);
    final receipt = await api.loadAccountClosureReceipt();
    expect(receipt?.operationId, receiptId);
    expect(api.getAuthToken(), isNull);
    final status = await api.getAccountClosureStatus(receipt!);
    expect(status.state, AccountClosureState.reviewRequired);
    expect(status.lawfulRetention, isTrue);
    expect(requests.last.headers['Authorization'], 'Bearer $receiptToken');
    expect(requests.last.url.query, isEmpty);
    expect(jsonDecode(requests.last.body), {'operationId': receiptId});
  });

  test('invalid receipt prevents account deletion', () async {
    api.setAuthTokenForTesting(_jwtFor('synthetic-user'));
    final methods = <String>[];
    api.setHttpClient(MockClient((request) async {
      methods.add(request.method);
      return http.Response(
          '{"success":true,"closure":{"operationId":"invalid","statusToken":"invalid"}}',
          200);
    }));
    await expectLater(api.deleteMyAccount(), throwsFormatException);
    expect(methods, ['POST']);
    expect(api.getAuthToken(), isNotNull);
  });

  test('unrecognized closure state cannot become completed', () async {
    api.setHttpClient(MockClient((request) async =>
        http.Response('{"data":{"state":"all_erased"}}', 200)));
    await expectLater(
        api.getAccountClosureStatus(AccountClosureReceipt(
            operationId: receiptId, statusToken: receiptToken)),
        throwsFormatException);
  });

  test('a late prepare cannot delete a different account', () async {
    api.setAuthTokenForTesting(_jwtFor('synthetic-A'));
    final waiting = Completer<http.Response>();
    final entered = Completer<void>();
    var deletes = 0;
    api.setHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/prepare')) {
        entered.complete();
        return waiting.future;
      }
      deletes++;
      return http.Response('{"success":true}', 200);
    }));
    final pending = api.deleteMyAccount();
    await entered.future;
    final other = _jwtFor('synthetic-B');
    api.setAuthTokenForTesting(other);
    waiting.complete(preparedReceipt());
    await expectLater(pending, throwsStateError);
    expect(deletes, 0);
    expect(api.getAuthToken(), other);
  });

  test('failed receipt persistence prevents DELETE', () async {
    api.setAuthTokenForTesting(_jwtFor('synthetic-user'));
    api.resetCredentialStoreForTesting(store: FailedReceiptStore());
    final methods = <String>[];
    api.setHttpClient(MockClient((request) async {
      methods.add(request.method);
      return preparedReceipt();
    }));
    await expectLater(api.deleteMyAccount(), throwsStateError);
    expect(methods, ['POST']);
    expect(api.getAuthToken(), isNotNull);
  });
}
