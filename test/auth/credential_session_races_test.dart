import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
String jwt(String id) => 'e30.${base64Url.encode(utf8.encode(jsonEncode({
          'id': id,
          'exp': 2100000000
        }))).replaceAll('=', '')}.synthetic';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;
  late Map<String, String> secure;
  late Set<String> failedDeletes;
  Completer<void>? writeBarrier;
  Completer<void>? writeEntered;
  var failAWrite = false;
  // Holds the secure write of one credential, so its commit stays in flight.
  String? heldValue;
  Completer<void>? heldRelease;
  Completer<void>? heldEntered;

  setUp(() {
    heldValue = null;
    heldRelease = null;
    heldEntered = null;
    api = BackendApiService();
    SharedPreferences.setMockInitialValues({});
    secure = {};
    failedDeletes = {};
    writeBarrier = null;
    writeEntered = null;
    failAWrite = false;
    api.resetCredentialStoreForTesting();
    api.setAuthTokenForTesting(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      if (call.method == 'read') return secure[key];
      if (call.method == 'delete') {
        if (failedDeletes.contains(key)) {
          throw PlatformException(code: 'synthetic-delete-failure');
        }
        secure.remove(key);
        return null;
      }
      if (call.method == 'write') {
        final value = args['value'] as String;
        if (value == heldValue) {
          if (heldEntered != null && !heldEntered!.isCompleted) {
            heldEntered!.complete();
          }
          await heldRelease?.future;
        }
        if (value == jwt('A')) {
          if (writeEntered != null && !writeEntered!.isCompleted) {
            writeEntered!.complete();
          }
          await writeBarrier?.future;
          if (failAWrite) {
            throw PlatformException(code: 'synthetic-write-failure');
          }
        }
        secure[key] = value;
        return null;
      }
      throw StateError('Unexpected credential operation');
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  for (final newerAccount in [false, true]) {
    test(
        'delayed login cannot restore after ${newerAccount ? 'account B login' : 'logout'}',
        () async {
      final entered = Completer<void>();
      final response = Completer<void>();
      api.setHttpClient(MockClient((_) async {
        entered.complete();
        await response.future;
        return http.Response(
            jsonEncode(
                {'token': jwt('A'), 'refreshToken': 'synthetic-refresh-A'}),
            200);
      }));
      final login = api.loginWithEmail(
          email: 'synthetic@example.invalid', password: 'synthetic-not-real');
      final rejected = expectLater(login, throwsStateError);
      await entered.future;
      await api.clearAuth();
      if (newerAccount) await api.setAuthToken(jwt('B'));
      response.complete();
      await rejected;
      expect(api.getAuthToken(), newerAccount ? jwt('B') : isNull);
      expect(secure['jwt_token'], newerAccount ? jwt('B') : isNull);
      expect(secure['refresh_token'], isNull);
    });
  }

  for (final failWrite in [false, true]) {
    test(
        'interleaved ${failWrite ? 'failed' : 'late'} A commit cannot revoke/mix B credential pair',
        () async {
      writeBarrier = Completer<void>();
      writeEntered = Completer<void>();
      failAWrite = failWrite;
      final a = api.persistAuthTokensFromResponse(
          {'token': jwt('A'), 'refreshToken': 'synthetic-refresh-A'});
      final rejected = expectLater(a, throwsA(anything));
      await writeEntered!.future;
      final b = api.persistAuthTokensFromResponse(
          {'token': jwt('B'), 'refreshToken': 'synthetic-refresh-B'});
      writeBarrier!.complete();
      await rejected;
      expect(await b, isTrue);
      expect(api.getAuthToken(), jwt('B'));
      expect(secure['jwt_token'], jwt('B'));
      expect(secure['refresh_token'], 'synthetic-refresh-B');
    });
  }

  test(
      'logout attempts refresh deletion despite JWT failure and restart cannot load retained JWT',
      () async {
    await api.persistAuthTokensFromResponse(
        {'token': jwt('A'), 'refreshToken': 'synthetic-refresh-A'});
    failedDeletes.add('jwt_token');
    await api.clearAuth();
    expect(api.getAuthToken(), isNull);
    expect(secure['refresh_token'], isNull);
    expect(
        (await SharedPreferences.getInstance())
            .getBool(AuthCredentialStore.revokedKey),
        isTrue);
    api.resetCredentialStoreForTesting();
    await api.loadAuthToken();
    expect(api.getAuthToken(), isNull);
  });

  group('a wallet-signed session started under account A', () {
    /// Serves the wallet challenge, and a login that would issue A's session.
    void serveWalletLoginForA() {
      api.setHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/challenge')) {
          return http.Response(
              jsonEncode({'message': 'synthetic-challenge'}), 200);
        }
        if (request.url.path.endsWith('/api/auth/login')) {
          return http.Response(
              jsonEncode({
                'token': jwt('A'),
                'refreshToken': 'synthetic-refresh-A',
              }),
              200);
        }
        return http.Response('{}', 404);
      }));
    }

    test(
        'a signature that lands after the session moved to B does not commit A',
        () async {
      await api.setAuthToken(jwt('A'));
      serveWalletLoginForA();
      final signRequested = Completer<void>();
      final signature = Completer<String>();
      final renewal = api.ensureSessionForActiveSigner(
        walletAddress: 'synthetic-wallet-a',
        signMessage: (_) {
          signRequested.complete();
          return signature.future;
        },
      );
      final rejected = expectLater(renewal, throwsStateError);
      await signRequested.future;
      await api.setAuthToken(jwt('B'));
      signature.complete('synthetic-signature');
      await rejected;
      expect(api.getAuthToken(), jwt('B'));
      expect(secure['jwt_token'], jwt('B'));
      expect(secure['refresh_token'], isNot('synthetic-refresh-A'));
    });

    test('a signature that lands after logout does not restore A', () async {
      await api.setAuthToken(jwt('A'));
      serveWalletLoginForA();
      final signRequested = Completer<void>();
      final signature = Completer<String>();
      final renewal = api.ensureSessionForActiveSigner(
        walletAddress: 'synthetic-wallet-a',
        signMessage: (_) {
          signRequested.complete();
          return signature.future;
        },
      );
      final rejected = expectLater(renewal, throwsStateError);
      await signRequested.future;
      await api.clearAuth();
      signature.complete('synthetic-signature');
      await rejected;
      expect(api.getAuthToken(), isNull);
      expect(secure['jwt_token'], isNull);
      expect(secure['refresh_token'], isNull);
    });

    test(
        'two concurrent ensures of the same wallet both resolve to its session',
        () async {
      const wallet = 'synthetic-wallet-a';
      final walletToken = 'e30.${base64Url.encode(utf8.encode(jsonEncode({
                'id': 'A',
                'walletAddress': wallet,
                'authLevel': 'wallet_signed',
                'exp': 2100000000,
              }))).replaceAll('=', '')}.synthetic';
      api.setHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/challenge')) {
          return http.Response(
              jsonEncode({'message': 'synthetic-challenge'}), 200);
        }
        if (request.url.path.endsWith('/api/auth/login')) {
          return http.Response(jsonEncode({'token': walletToken}), 200);
        }
        return http.Response('{}', 404);
      }));
      final signatures = <Completer<String>>[];
      Future<String> sign(String _) {
        final signature = Completer<String>();
        signatures.add(signature);
        return signature.future;
      }

      // Neither caller names a session; both start while none is signed in.
      final first = api.ensureSessionForActiveSigner(
          walletAddress: wallet, signMessage: sign);
      final second = api.ensureSessionForActiveSigner(
          walletAddress: wallet, signMessage: sign);
      while (signatures.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }

      signatures[0].complete('synthetic-signature-1');
      expect((await first).token, walletToken);
      signatures[1].complete('synthetic-signature-2');
      expect((await second).token, walletToken,
          reason: 'the wallet already holds a valid session; nothing throws');
      expect(api.getAuthToken(), walletToken);
    });

    group('a caller that names no session', () {
      /// The same account under another credential, as a link or a non-wallet
      /// sign-in token swap issues.
      String swapped(String id) =>
          'e30.${base64Url.encode(utf8.encode(jsonEncode({
                    'id': id,
                    'iat': 1,
                    'exp': 2100000000,
                  }))).replaceAll('=', '')}.synthetic';

      test('is bound to the account at entry: A to B during the signature',
          () async {
        await api.setAuthToken(jwt('A'));
        var loginRequests = 0;
        final base = MockClient((request) async {
          if (request.url.path.endsWith('/api/auth/login')) loginRequests += 1;
          if (request.url.path.endsWith('/api/auth/challenge')) {
            return http.Response(
                jsonEncode({'message': 'synthetic-challenge'}), 200);
          }
          return http.Response(jsonEncode({'token': jwt('A')}), 200);
        });
        api.setHttpClient(base);
        final signRequested = Completer<void>();
        final signature = Completer<String>();
        final renewal = api.ensureSessionForActiveSigner(
          walletAddress: 'synthetic-wallet-a',
          signMessage: (_) {
            signRequested.complete();
            return signature.future;
          },
        );
        final rejected = expectLater(renewal, throwsStateError);
        await signRequested.future;
        await api.setAuthToken(jwt('B'));
        signature.complete('synthetic-signature');
        await rejected;
        expect(loginRequests, 0);
        expect(api.getAuthToken(), jwt('B'));
      });

      /// Starts the renewal of A, held on the signature, with A signed in.
      Future<
          ({
            Future<Object?> outcome,
            Completer<String> signature,
            ValueGetter<int> logins
          })> startHeldRenewal() async {
        await api.setAuthToken(jwt('A'));
        var logins = 0;
        api.setHttpClient(MockClient((request) async {
          if (request.url.path.endsWith('/api/auth/challenge')) {
            return http.Response(
                jsonEncode({'message': 'synthetic-challenge'}), 200);
          }
          if (request.url.path.endsWith('/api/auth/login')) logins += 1;
          return http.Response(jsonEncode({'token': jwt('A')}), 200);
        }));
        final signRequested = Completer<void>();
        final signature = Completer<String>();
        final renewal = api
            .ensureSessionForActiveSigner(
              walletAddress: 'synthetic-wallet-a',
              signMessage: (_) {
                signRequested.complete();
                return signature.future;
              },
            )
            .then<Object?>((value) => value, onError: (Object e) => e);
        await signRequested.future;
        return (outcome: renewal, signature: signature, logins: () => logins);
      }

      test(
          "refuses A's signature while B's sign-in is committing, and B completes as B",
          () async {
        final held = await startHeldRenewal();
        heldValue = jwt('B');
        heldRelease = Completer<void>();
        heldEntered = Completer<void>();
        final bSignIn = api.setAuthToken(jwt('B'));
        await heldEntered!.future;
        // B is the pending target; the live token is still A's.
        expect(api.pendingAuthAccountKey, 'B');
        expect(api.getAuthToken(), jwt('A'));

        held.signature.complete('synthetic-signature');
        expect(await held.outcome, isA<StateError>());
        expect(held.logins(), 0);

        heldRelease!.complete();
        await bSignIn;
        expect(api.getAuthToken(), jwt('B'));
        expect(secure['jwt_token'], jwt('B'));
      });

      test("refuses A's signature once B's sign-in has committed", () async {
        final held = await startHeldRenewal();
        await api.setAuthToken(jwt('B'));
        held.signature.complete('synthetic-signature');
        expect(await held.outcome, isA<StateError>());
        expect(held.logins(), 0);
        expect(api.getAuthToken(), jwt('B'));
      });

      test('resolves while the same account swap is still committing',
          () async {
        final held = await startHeldRenewal();
        heldValue = swapped('A');
        heldRelease = Completer<void>();
        heldEntered = Completer<void>();
        final swap = api.setAuthToken(swapped('A'));
        await heldEntered!.future;
        expect(api.pendingAuthAccountKey, 'A');

        held.signature.complete('synthetic-signature');
        await pumpEventQueue();
        heldRelease!.complete();
        // The wallet login commits after, and supersedes, the swap in flight.
        await swap.then<Object?>((_) => null, onError: (Object _) => null);
        expect(await held.outcome, isNot(isA<StateError>()));
        expect(held.logins(), 1);
      });

      test('the pending account follows commit and logout', () async {
        expect(api.pendingAuthAccountKey, '');
        await api.setAuthToken(jwt('A'));
        expect(api.pendingAuthAccountKey, 'A');
        expect(api.hasPendingAccountSwitch, isFalse);
        await api.clearAuth();
        expect(api.pendingAuthAccountKey, '');
      });

      test(
          'resolves when the same account swaps its token during the signature',
          () async {
        await api.setAuthToken(jwt('A'));
        serveWalletLoginForA();
        final signRequested = Completer<void>();
        final signature = Completer<String>();
        final renewal = api.ensureSessionForActiveSigner(
          walletAddress: 'synthetic-wallet-a',
          signMessage: (_) {
            signRequested.complete();
            return signature.future;
          },
        );
        await signRequested.future;
        await api.setAuthToken(swapped('A'));
        signature.complete('synthetic-signature');

        expect((await renewal).token, jwt('A'));
        expect(api.getAuthToken(), jwt('A'));
      });

      test('resolves for a guest: no session to the one this call creates',
          () async {
        serveWalletLoginForA();
        final payload = await api.ensureSessionForActiveSigner(
          walletAddress: 'synthetic-wallet-a',
          signMessage: (_) async => 'synthetic-signature',
        );
        expect(payload.token, jwt('A'));
        expect(api.getAuthToken(), jwt('A'));
      });

      test('refuses a guest whose session another account created meanwhile',
          () async {
        serveWalletLoginForA();
        final signRequested = Completer<void>();
        final signature = Completer<String>();
        final renewal = api.ensureSessionForActiveSigner(
          walletAddress: 'synthetic-wallet-a',
          signMessage: (_) {
            signRequested.complete();
            return signature.future;
          },
        );
        final rejected = expectLater(renewal, throwsStateError);
        await signRequested.future;
        await api.setAuthToken(jwt('B'));
        signature.complete('synthetic-signature');
        await rejected;
        expect(api.getAuthToken(), jwt('B'));
      });
    });

    test('a renewal whose session ended before it was requested does not sign',
        () async {
      await api.setAuthToken(jwt('A'));
      serveWalletLoginForA();
      final startedUnder = api.authSessionEpoch;
      await api.setAuthToken(jwt('B'));
      var signed = false;
      await expectLater(
        api.ensureSessionForActiveSigner(
          walletAddress: 'synthetic-wallet-a',
          signMessage: (_) async {
            signed = true;
            return 'synthetic-signature';
          },
          expectedEpoch: startedUnder,
        ),
        throwsStateError,
      );
      expect(signed, isFalse);
      expect(api.getAuthToken(), jwt('B'));
      expect(secure['jwt_token'], jwt('B'));
    });
  });
}
