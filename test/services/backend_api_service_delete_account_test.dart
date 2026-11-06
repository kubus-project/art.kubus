import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:art_kubus/models/account_closure.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

String walletJwt(String wallet, {String level = 'wallet_signed'}) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({
        'id': 'synthetic-user',
        'walletAddress': wallet,
        'authLevel': level,
        'exp': 2100000000
      })))
      .replaceAll('=', '');
  return 'e30.$payload.';
}

/// In-memory secure storage. The platform plugin is not available to tests.
class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<void> write(
      {required String key,
      required String? value,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read(
          {required String key,
          IOSOptions? iOptions,
          AndroidOptions? aOptions,
          LinuxOptions? lOptions,
          WebOptions? webOptions,
          MacOsOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      values[key];

  @override
  Future<void> delete(
      {required String key,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    values.remove(key);
  }
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
            operationId: receiptId,
            statusToken: receiptToken,
            accountId: 'synthetic-user')),
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

  for (final deprecated in [false, true]) {
    test(
        'wallet closure alias (deprecated=$deprecated) shares prepared account closure',
        () async {
      const wallet = '11111111111111111111111111111111';
      api.setAuthTokenForTesting(walletJwt(wallet));
      final paths = <String>[];
      api.setHttpClient(MockClient((request) async {
        paths.add(request.url.path);
        return request.url.path.endsWith('/prepare')
            ? preparedReceipt()
            : http.Response('{"success":true}', 200);
      }));
      if (deprecated) {
        // Intentionally exercise the existing deprecated public entry point.
        // ignore: deprecated_member_use_from_same_package
        await api.deleteMyAccountData(walletAddress: wallet);
      } else {
        await api.deleteMyWalletScopedData(walletAddress: wallet);
      }
      expect(paths, ['/api/auth/account-closure/prepare', '/api/auth/me']);
      expect((await api.loadAccountClosureReceipt())?.operationId, receiptId);
      expect(api.getAuthToken(), isNull);
    });
  }

  test('wallet alias rejects another wallet without switching auth or sending',
      () async {
    final original = walletJwt('11111111111111111111111111111111');
    api.setAuthTokenForTesting(original);
    var requests = 0;
    api.setHttpClient(MockClient((_) async {
      requests++;
      return preparedReceipt();
    }));
    await expectLater(
        api.deleteMyWalletScopedData(
            walletAddress: '22222222222222222222222222222222'),
        throwsStateError);
    expect(requests, 0);
    expect(api.getAuthToken(), original);
  });

  test('wallet alias retains wallet-signed authority requirement', () async {
    api.setAuthTokenForTesting(
        walletJwt('11111111111111111111111111111111', level: 'account_linked'));
    var requests = 0;
    api.setHttpClient(MockClient((_) async {
      requests++;
      return preparedReceipt();
    }));
    await expectLater(api.deleteMyWalletScopedData(), throwsStateError);
    expect(requests, 0);
  });

  group('account-bound closure receipt', () {
    late AuthCredentialStore store;

    setUp(() {
      store =
          AuthCredentialStore(web: true, secureStorage: _MemorySecureStorage());
      api.resetCredentialStoreForTesting(store: store);
    });

    http.Response acceptedOrPrepared(http.Request request) =>
        request.url.path.endsWith('/prepare')
            ? preparedReceipt()
            : http.Response('{"success":true}', 200);

    Future<void> closeAccount(String userId) async {
      api.setAuthTokenForTesting(_jwtFor(userId));
      api.setHttpClient(MockClient((r) async => acceptedOrPrepared(r)));
      await api.deleteMyAccount();
    }

    test('the stored receipt is bound to the account that requested it',
        () async {
      await closeAccount('synthetic-A');

      final receipt = await api.loadAccountClosureReceipt();
      expect(receipt?.operationId, receiptId);
      expect(receipt?.accountId, 'synthetic-A');
    });

    test('signed in as another account, a stored receipt is never recovered',
        () async {
      await closeAccount('synthetic-A');

      api.setAuthTokenForTesting(_jwtFor('synthetic-B'));
      expect(await api.loadAccountClosureReceipt(), isNull);

      api.setAuthTokenForTesting(_jwtFor('synthetic-A'));
      expect((await api.loadAccountClosureReceipt())?.operationId, receiptId,
          reason: 'the receipt stays recoverable for its own account');
    });

    test(
        'signing in as another account purges the receipt, so a later '
        'signed-out view cannot show it', () async {
      await closeAccount('synthetic-A');

      await api.setAuthToken(_jwtFor('synthetic-B'));
      await api.clearAuth();

      expect(await api.loadAccountClosureReceipt(), isNull);
      expect(await store.readClosureReceipt(), isNull);
    });

    test('an unbound stored receipt is purged rather than recovered', () async {
      await store.saveClosureReceipt(
          '{"operationId":"$receiptId","statusToken":"$receiptToken"}');

      expect(await api.loadAccountClosureReceipt(), isNull);
      expect(await store.readClosureReceipt(), isNull);
    });

    test('signed in, a foreign receipt cannot be saved', () async {
      api.setAuthTokenForTesting(_jwtFor('synthetic-B'));

      await expectLater(
        api.saveAccountClosureReceipt(AccountClosureReceipt(
            operationId: receiptId,
            statusToken: receiptToken,
            accountId: 'synthetic-A')),
        throwsStateError,
      );
      expect(await store.readClosureReceipt(), isNull);
    });

    test(
        'a lost DELETE response keeps the receipt, sends DELETE once, and '
        'reports deleting rather than refused', () async {
      api.setAuthTokenForTesting(_jwtFor('synthetic-A'));
      var deletes = 0;
      final stages = <AccountClosureStage>[];
      api.setHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/prepare')) return preparedReceipt();
        deletes += 1;
        throw TimeoutException('synthetic lost response');
      }));

      await expectLater(
        api.deleteMyAccount(onStage: (stage, _) => stages.add(stage)),
        throwsA(isA<TimeoutException>()),
      );

      expect(deletes, 1, reason: 'the service never retries DELETE itself');
      expect(stages,
          [AccountClosureStage.preparing, AccountClosureStage.deleting]);
      expect((await api.loadAccountClosureReceipt())?.accountId, 'synthetic-A',
          reason: 'the status receipt survives so the closure can be checked');
    });

    for (final status in [401, 404, 408, 409, 500, 503]) {
      test(
          'ambiguous DELETE answer $status is not a refusal: receipt kept, '
          'stage stays deleting', () async {
        api.setAuthTokenForTesting(_jwtFor('synthetic-A'));
        final stages = <AccountClosureStage>[];
        api.setHttpClient(MockClient((request) async {
          if (request.url.path.endsWith('/prepare')) return preparedReceipt();
          return http.Response('{"success":false}', status);
        }));

        await expectLater(
          api.deleteMyAccount(onStage: (stage, _) => stages.add(stage)),
          throwsA(isA<BackendApiRequestException>()),
        );

        expect(stages.last, AccountClosureStage.deleting);
        expect(
            (await api.loadAccountClosureReceipt())?.accountId, 'synthetic-A');
      });
    }

    test(
        'a definitive DELETE refusal discards the receipt, reports refused, '
        'and keeps the session', () async {
      api.setAuthTokenForTesting(_jwtFor('synthetic-A'));
      final stages = <AccountClosureStage>[];
      api.setHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/prepare')) return preparedReceipt();
        return http.Response('{"success":false}', 403);
      }));

      await expectLater(
        api.deleteMyAccount(onStage: (stage, _) => stages.add(stage)),
        throwsA(isA<BackendApiRequestException>()),
      );

      expect(stages, [
        AccountClosureStage.preparing,
        AccountClosureStage.deleting,
        AccountClosureStage.refused,
      ]);
      expect(await api.loadAccountClosureReceipt(), isNull,
          reason: 'a refused closure must not quarantine a live account');
      expect(api.getAuthToken(), isNotNull);
    });

    test(
        'a pending closure refuses sign-in for its account before any secret '
        'is written, and a different account is still accepted', () async {
      api.setAuthTokenForTesting(_jwtFor('synthetic-A'));
      api.setHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/prepare')) return preparedReceipt();
        throw TimeoutException('synthetic lost response');
      }));
      await expectLater(
          api.deleteMyAccount(), throwsA(isA<TimeoutException>()));
      await api.clearAuth();

      await expectLater(
          api.setAuthToken(_jwtFor('synthetic-A')), throwsStateError);
      expect(api.getAuthToken(), isNull);
      expect(await store.readAccess(), isNull);
      expect(await api.loadAccountClosureReceipt(), isNotNull,
          reason: 'refusal keeps the receipt');

      await api.setAuthToken(_jwtFor('synthetic-B'));
      expect(api.getAuthToken(), _jwtFor('synthetic-B'));
    });

    test(
        'a restored session for an account with a pending receipt is not '
        'restored', () async {
      await closeAccount('synthetic-A');
      await store.saveSession(_jwtFor('synthetic-A'), null);
      api.setAuthTokenForTesting(null);
      expect(await api.loadAccountClosureReceipt(), isNotNull);

      await api.loadAuthToken();

      expect(api.getAuthToken(), isNull);
    });

    test('removing the receipt on this device lifts the quarantine', () async {
      await closeAccount('synthetic-A');
      await api.clearAccountClosureReceipt();

      await api.setAuthToken(_jwtFor('synthetic-A'));

      expect(api.getAuthToken(), isNotNull);
    });
  });
}
