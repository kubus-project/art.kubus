import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/browser_session/browser_session_api.dart';
import 'package:art_kubus/services/browser_session/browser_session_controller.dart';
import 'package:art_kubus/services/browser_session/browser_session_lock.dart';
import 'package:art_kubus/services/browser_session/browser_session_logout_intent_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

String jwt(String id) => 'e30.${base64Url.encode(utf8.encode(jsonEncode({
          'id': id,
          'exp': 2100000000,
        }))).replaceAll('=', '')}.synthetic';

String sessionJwt(String id,
        {String account = 'acct-1',
        String family = 'browser-session-family'}) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode({
              'id': account,
              'bsid': family,
              'exp': 2100000000,
              'nonce': id,
            }))).replaceAll('=', '')}.synthetic';

String expiredSessionJwt(String id,
        {String account = 'acct-1',
        String family = 'browser-session-family'}) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode({
              'id': account,
              'bsid': family,
              'exp': 1000,
              'nonce': id,
            }))).replaceAll('=', '')}.synthetic';

/// Scripted browser-session API: every outcome is set by the test.
class ScriptedSessionApi implements BrowserSessionApi {
  int issueCalls = 0;
  int restoreCalls = 0;
  int logoutCalls = 0;
  String? lastLoginToken;
  Completer<void>? restoreGate;
  Completer<void>? issueGate;
  Completer<void>? logoutGate;
  void Function()? onLogout;
  BrowserSessionResult Function() logoutScript =
      () => BrowserSessionResult.success({'success': true});

  BrowserSessionResult Function() issueScript =
      () => BrowserSessionResult.success({
            'success': true,
            'data': {
              'token': jwt('session'),
              'user': {'id': 'acct-1'}
            },
          });
  BrowserSessionResult Function() restoreScript =
      () => BrowserSessionResult.success({
            'success': true,
            'data': {
              'token': jwt('restored'),
              'user': {'id': 'acct-1'}
            },
          });

  @override
  Future<BrowserSessionResult> issue({required String loginToken}) async {
    issueCalls += 1;
    lastLoginToken = loginToken;
    final gate = issueGate;
    if (gate != null) await gate.future;
    return issueScript();
  }

  @override
  Future<BrowserSessionResult> restore() async {
    restoreCalls += 1;
    final gate = restoreGate;
    if (gate != null) await gate.future;
    return restoreScript();
  }

  @override
  Future<BrowserSessionResult> logout() async {
    logoutCalls += 1;
    onLogout?.call();
    final gate = logoutGate;
    if (gate != null) await gate.future;
    return logoutScript();
  }
}

/// Marker storage whose writes or reads can be made to fail, modelling browser
/// storage that refuses a write (quota, disabled) and later accepts it again.
class FlakyIntentStore implements BrowserSessionLogoutIntentStore {
  FlakyIntentStore() : _inner = createBrowserSessionLogoutIntentStore();

  final BrowserSessionLogoutIntentStore _inner;
  bool writesFail = false;
  bool readsFail = false;

  @override
  Future<bool> writePendingLogout({bool sharedMarkerWritten = false}) async =>
      writesFail
          ? false
          : _inner.writePendingLogout(sharedMarkerWritten: sharedMarkerWritten);

  @override
  Future<bool> readDependsOnSharedMarker() =>
      _inner.readDependsOnSharedMarker();

  @override
  Future<bool?> readPendingLogout() async =>
      readsFail ? null : _inner.readPendingLogout();

  @override
  Future<bool> clear() => _inner.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendApiService api;
  late ScriptedSessionApi session;
  late Map<String, String> secure;
  late List<String> secureWrites;

  setUp(() {
    api = BackendApiService();
    SharedPreferences.setMockInitialValues({});
    secure = {};
    secureWrites = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      if (call.method == 'read') return secure[key];
      if (call.method == 'delete') {
        secure.remove(key);
        return null;
      }
      if (call.method == 'write') {
        final value = args['value'] as String;
        secureWrites.add(value);
        secure[key] = value;
        return null;
      }
      throw StateError('Unexpected credential operation');
    });
    // Web credential semantics: the bearer lives in tab memory only.
    api.resetCredentialStoreForTesting(store: AuthCredentialStore(web: true));
    api.setAuthTokenForTesting(null);
    session = ScriptedSessionApi();
    api.debugSetBrowserSessionForTesting(
      BrowserSessionController(
          api: session, lock: InProcessBrowserSessionLock()),
      isWeb: () => true,
    );
  });

  tearDown(() {
    api.debugSetBrowserSessionForTesting(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  /// Email login endpoint answering with [loginToken].
  void serveEmailLogin(String loginToken) {
    api.setHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/api/auth/login/email')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'token': loginToken,
              'user': {'id': 'acct-1'},
              'authProvider': 'email',
            },
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    }));
  }

  /// No credential may reach preferences or any storage the web app writes.
  Future<void> expectNoCredentialStorage(String token) async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('jwt_token'), isFalse);
    expect(prefs.containsKey('refresh_token'), isFalse);
    for (final key in prefs.getKeys()) {
      expect('${prefs.get(key)}', isNot(contains(token)));
    }
    expect(secure.values.where((v) => v.contains(token)), isEmpty);
    expect(secureWrites.where((v) => v.startsWith('e30.')), isEmpty);
  }

  group('email login on web', () {
    test('issues a session and keeps only the session-bound bearer', () async {
      serveEmailLogin(jwt('login'));

      await api.loginWithEmail(
          email: 'a@example.invalid', password: 'pw-pw-pw-pw');

      expect(session.issueCalls, 1);
      expect(session.lastLoginToken, jwt('login'));
      expect(api.getAuthToken(), jwt('session'));
      expect(api.getAuthToken(), isNot(jwt('login')));
      expect(api.browserSessionBearerActive, isTrue);
      await expectNoCredentialStorage(jwt('session'));
      await expectNoCredentialStorage(jwt('login'));
    });

    test('when issue fails the user stays signed in for this tab only',
        () async {
      serveEmailLogin(jwt('login'));
      session.issueScript = () => BrowserSessionResult.failure(
          BrowserSessionOutcome.disabled,
          statusCode: 404);

      await api.loginWithEmail(
          email: 'a@example.invalid', password: 'pw-pw-pw-pw');

      expect(api.getAuthToken(), jwt('login'));
      expect(api.browserSessionBearerActive, isFalse);
      await expectNoCredentialStorage(jwt('login'));
    });

    test('a transient issue failure does not throw out of the sign-in',
        () async {
      serveEmailLogin(jwt('login'));
      session.issueScript = () => const BrowserSessionResult.unavailable();

      final result = await api.loginWithEmail(
          email: 'a@example.invalid', password: 'pw-pw-pw-pw');

      expect(result['success'], isTrue);
      expect(api.getAuthToken(), jwt('login'));
    });

    test('A to B issue failure confirms cookie revocation before fallback',
        () async {
      serveEmailLogin(jwt('login-a'));
      await api.loginWithEmail(
          email: 'a@example.invalid', password: 'pw-pw-pw-pw');
      session.onLogout = () {
        session.restoreScript = () => BrowserSessionResult.failure(
            BrowserSessionOutcome.invalid,
            statusCode: 401);
      };
      session.issueScript = () => const BrowserSessionResult.unavailable();
      serveEmailLogin(jwt('login-b'));

      await api.loginWithEmail(
          email: 'b@example.invalid', password: 'pw-pw-pw-pw');
      expect(api.getAuthToken(), jwt('login-b'));
      expect(session.logoutCalls, 3);
      await api.clearAuth();
      expect(await api.restoreBrowserSessionForStart(), isFalse);
      expect(api.getAuthToken(), isNull);
    });

    test('failed cookie revocation denies an email account switch', () async {
      serveEmailLogin(jwt('login-a'));
      await api.loginWithEmail(
          email: 'a@example.invalid', password: 'pw-pw-pw-pw');
      session.logoutScript = () => const BrowserSessionResult.unavailable();
      serveEmailLogin(jwt('login-b'));

      await expectLater(
        api.loginWithEmail(email: 'b@example.invalid', password: 'pw-pw-pw-pw'),
        throwsStateError,
      );
      expect(api.getAuthToken(), jwt('session'));
      expect(session.issueCalls, 1);
    });

    test('native never calls the session client', () async {
      api.debugSetBrowserSessionForTesting(
        BrowserSessionController(
            api: session, lock: InProcessBrowserSessionLock()),
        isWeb: () => false,
      );
      serveEmailLogin(jwt('login'));

      await api.loginWithEmail(
          email: 'a@example.invalid', password: 'pw-pw-pw-pw');
      expect(api.getAuthToken(), jwt('login'));

      // With no bearer, a native start must not restore either.
      await api.clearAuth();
      expect(await api.restoreExistingSession(allowRefresh: false), isFalse);
      await api.endBrowserSessionForLogout();

      expect(session.issueCalls, 0);
      expect(session.restoreCalls, 0);
      expect(session.logoutCalls, 0);
      expect(api.getAuthToken(), isNull);
    });
  });

  group('restore on start', () {
    test('a successful restore hydrates the bearer like an email sign-in',
        () async {
      expect(api.getAuthToken(), isNull);

      final restored = await api.restoreBrowserSessionForStart();

      expect(restored, isTrue);
      expect(session.restoreCalls, 1);
      expect(api.getAuthToken(), jwt('restored'));
      expect(api.browserSessionBearerActive, isTrue);
      await expectNoCredentialStorage(jwt('restored'));
    });

    test('a refused restore settles to guest and is not retried', () async {
      session.restoreScript = () => BrowserSessionResult.failure(
          BrowserSessionOutcome.invalid,
          statusCode: 401);

      expect(await api.restoreExistingSession(allowRefresh: false), isFalse);
      expect(api.getAuthToken(), isNull);
      expect(await api.restoreExistingSession(allowRefresh: false), isFalse);

      expect(session.restoreCalls, 1);
      expect(api.getAuthToken(), isNull);
    });

    test('a 503 keeps the tab signed out and backs off before retrying',
        () async {
      session.restoreScript = () => const BrowserSessionResult.unavailable();

      expect(await api.restoreExistingSession(allowRefresh: false), isFalse);
      expect(await api.restoreExistingSession(allowRefresh: false), isFalse);

      expect(session.restoreCalls, 1);
      expect(api.getAuthToken(), isNull);
    });

    test('overlapping restores in one tab make a single restore call',
        () async {
      session.restoreGate = Completer<void>();

      final first = api.restoreExistingSession(allowRefresh: false);
      final second = api.restoreExistingSession(allowRefresh: false);
      session.restoreGate!.complete();

      expect(await Future.wait([first, second]), [true, true]);
      expect(session.restoreCalls, 1);
      expect(api.getAuthToken(), jwt('restored'));
    });

    test('a start restore remains pending until the cookie request settles',
        () async {
      session.restoreGate = Completer<void>();

      var settled = false;
      final restore = api.restoreBrowserSessionForStart().then((value) {
        settled = true;
        return value;
      });
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(settled, isFalse);
      expect(api.getAuthToken(), isNull);
      session.restoreGate!.complete();
      expect(await restore, isTrue);
      expect(api.getAuthToken(), jwt('restored'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(api.getAuthToken(), jwt('restored'));
    });

    test('settled restore failure is visible and is not replayed automatically',
        () async {
      session.restoreScript = () => const BrowserSessionResult.unavailable();
      expect(await api.restoreBrowserSessionForStart(), isFalse);
      expect(api.browserSessionRestoreUnavailable, isTrue);
      expect(session.restoreCalls, 1);
      expect(await api.restoreExistingSession(allowRefresh: false), isFalse);
      expect(session.restoreCalls, 1);
    });

    test(
        'startup wait expiry fences late restore while its cookie lock remains held',
        () async {
      session.restoreGate = Completer<void>();
      expect(
        await api.restoreBrowserSessionForStart(
          waitLimit: const Duration(milliseconds: 20),
        ),
        isFalse,
      );
      expect(api.browserSessionRestoreUnavailable, isTrue);
      expect(api.getAuthToken(), isNull);
      final logout = api.endBrowserSessionForLogout();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(session.logoutCalls, 0);
      session.restoreGate!.complete();
      await logout;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(api.getAuthToken(), isNull);
      expect(session.restoreCalls, 1);
      expect(session.logoutCalls, 1);
    });
  });

  group('logout', () {
    test('revokes the session and blocks restoration until the next sign-in',
        () async {
      await api.restoreBrowserSessionForStart();
      expect(api.browserSessionBearerActive, isTrue);

      await api.endBrowserSessionForLogout();
      await api.clearAuth();

      expect(session.logoutCalls, 1);
      expect(api.getAuthToken(), isNull);
      expect(api.browserSessionBearerActive, isFalse);
      expect(await api.restoreExistingSession(allowRefresh: false), isFalse);
      expect(session.restoreCalls, 1);
    });

    test('a failed revoke still clears local state', () async {
      await api.restoreBrowserSessionForStart();
      session.logoutScript = () => BrowserSessionResult.failure(
          BrowserSessionOutcome.unavailable,
          statusCode: 503);

      expect(await api.endBrowserSessionForLogout(), isFalse);
      await api.clearAuth();

      expect(api.getAuthToken(), isNull);
      expect(
        (await SharedPreferences.getInstance())
            .getBool('browser_session_pending_logout_v1'),
        isTrue,
      );
      expect(await api.restoreBrowserSessionForStart(), isFalse);
      expect(session.restoreCalls, 1);
      expect(session.logoutCalls, 2);
    });

    test('404 retains pending revocation through feature re-enable', () async {
      session.logoutScript = () => BrowserSessionResult.failure(
          BrowserSessionOutcome.disabled,
          statusCode: 404);
      expect(await api.endBrowserSessionForLogout(requireConfirmation: true),
          isTrue);
      expect(
        (await SharedPreferences.getInstance())
            .getBool('browser_session_pending_logout_v1'),
        isTrue,
      );
      session.logoutScript =
          () => BrowserSessionResult.success({'success': true});
      expect(await api.restoreBrowserSessionForStart(), isFalse);
      expect(session.restoreCalls, 0);
      expect(
        (await SharedPreferences.getInstance())
            .getBool('browser_session_pending_logout_v1'),
        isNull,
      );
    });
  });

  group('other sign-ins on web', () {
    /// Every request answers [body]: each sign-in below makes one request.
    void serveAll(Map<String, dynamic> body, {int status = 200}) {
      api.setHttpClient(MockClient((request) async {
        return http.Response(jsonEncode(body), status);
      }));
    }

    Map<String, dynamic> bearerBody(String token) => {
          'success': true,
          'data': {
            'token': token,
            'user': {'id': 'acct-2'},
          },
        };

    test('wallet sign-in ends the browser session before its bearer is kept',
        () async {
      String? tokenDuringRevoke = 'not revoked';
      session.onLogout = () => tokenDuringRevoke = api.getAuthToken();
      serveAll(bearerBody(jwt('wallet')));

      await api.loginWithWallet(
          walletAddress: 'wallet-1', signature: 'sig', message: 'msg');

      expect(session.logoutCalls, 1);
      expect(tokenDuringRevoke, isNull);
      expect(session.issueCalls, 0);
      expect(session.restoreCalls, 0);
      expect(api.getAuthToken(), jwt('wallet'));
      expect(api.browserSessionBearerActive, isFalse);
      await expectNoCredentialStorage(jwt('wallet'));
    });

    test('Google, passkey and email registration each end the browser session',
        () async {
      serveAll(bearerBody(jwt('google')));
      await api.loginWithGoogle(code: 'one-time-code', origin: 'web');
      expect(session.logoutCalls, 1);
      expect(api.getAuthToken(), jwt('google'));

      serveAll(bearerBody(jwt('passkey')));
      await api.verifyPasskeyLogin(responsePayload: {'id': 'credential-1'});
      expect(session.logoutCalls, 2);
      expect(api.getAuthToken(), jwt('passkey'));

      serveAll(bearerBody(jwt('register')), status: 201);
      await api.registerWithEmail(
          email: 'b@example.invalid', password: 'pw-pw-pw-pw');
      expect(session.logoutCalls, 3);
      expect(api.getAuthToken(), jwt('register'));
      expect(session.issueCalls, 0);
      expect(session.restoreCalls, 0);
    });

    test('a registration that returns no bearer ends nothing', () async {
      serveAll({
        'success': true,
        'data': {
          'user': {'id': 'acct-2'}
        },
      }, status: 201);

      await api.registerWithEmail(
          email: 'b@example.invalid', password: 'pw-pw-pw-pw');

      expect(session.logoutCalls, 0);
      expect(api.getAuthToken(), isNull);
    });

    test('a failed revoke denies wallet sign-in and preserves current account',
        () async {
      await api.restoreBrowserSessionForStart();
      final previousToken = api.getAuthToken();
      session.logoutScript = () => const BrowserSessionResult.unavailable();
      serveAll(bearerBody(jwt('wallet')));

      await expectLater(
        api.loginWithWallet(
            walletAddress: 'wallet-1', signature: 'sig', message: 'msg'),
        throwsStateError,
      );

      expect(session.logoutCalls, 1);
      expect(api.getAuthToken(), previousToken);
      expect(api.browserSessionBearerActive, isTrue);
    });

    test('a disabled browser-session endpoint keeps legacy wallet sign-in',
        () async {
      session.logoutScript = () => BrowserSessionResult.failure(
          BrowserSessionOutcome.disabled,
          statusCode: 404);
      serveAll(bearerBody(jwt('wallet')));

      final result = await api.loginWithWallet(
          walletAddress: 'wallet-1', signature: 'sig', message: 'msg');

      expect(session.logoutCalls, 1);
      expect(result['success'], isTrue);
      expect(api.getAuthToken(), jwt('wallet'));
    });

    test('native sign-in never calls the session client', () async {
      api.debugSetBrowserSessionForTesting(
        BrowserSessionController(
            api: session, lock: InProcessBrowserSessionLock()),
        isWeb: () => false,
      );
      serveAll(bearerBody(jwt('wallet')));

      await api.loginWithWallet(
          walletAddress: 'wallet-1', signature: 'sig', message: 'msg');

      expect(session.logoutCalls, 0);
      expect(api.getAuthToken(), jwt('wallet'));
    });

    test('bind-wallet from a session-bound bearer keeps the browser session',
        () async {
      await api.restoreBrowserSessionForStart();
      expect(api.browserSessionBearerActive, isTrue);
      serveAll(bearerBody(jwt('restored-bound')));

      await api.bindAuthenticatedWallet('wallet-1', signature: 'sig');

      expect(session.logoutCalls, 0);
      expect(api.getAuthToken(), jwt('restored-bound'));
      expect(api.browserSessionBearerActive, isTrue);
    });

    test('bind-wallet from an unbound bearer ends the browser session',
        () async {
      serveAll(bearerBody(jwt('wallet')));
      await api.loginWithWallet(
          walletAddress: 'wallet-1', signature: 'sig', message: 'msg');
      serveAll(bearerBody(jwt('bound-wallet')));

      await api.bindAuthenticatedWallet('wallet-2', signature: 'sig');

      expect(session.logoutCalls, 2);
      expect(api.getAuthToken(), jwt('bound-wallet'));
      expect(api.browserSessionBearerActive, isFalse);
    });
  });

  group('401 from the normal API', () {
    test('one restore then one retry with the restored bearer', () async {
      session.restoreScript = () => BrowserSessionResult.success({
            'success': true,
            'data': {'token': sessionJwt('restored')},
          });
      await api.restoreBrowserSessionForStart();
      var calls = 0;
      final seen = <String>[];
      api.setHttpClient(MockClient((request) async {
        // The client also reports the failed call to diagnostics; not counted.
        if (request.url.path != '/api/profiles/me') {
          return http.Response('{}', 200);
        }
        calls += 1;
        seen.add(
            '${request.method} ${request.url.path} ${request.headers['Authorization']}');
        if (calls == 1) {
          expect(request.headers['Authorization'],
              'Bearer ${sessionJwt('restored')}');
          return http.Response('{"success":false}', 401);
        }
        expect(request.headers['Authorization'],
            'Bearer ${sessionJwt('rotated')}');
        return http.Response('{"success":true,"data":{"id":"acct-1"}}', 200);
      }));
      session.restoreScript = () => BrowserSessionResult.success({
            'success': true,
            'data': {'token': sessionJwt('rotated')},
          });

      final profile = await api.getMyProfile();

      expect(profile['success'], isTrue, reason: '$seen');
      expect(calls, 2, reason: '$seen');
      expect(session.restoreCalls, 2);
      expect(api.getAuthToken(), sessionJwt('rotated'));
    });

    for (final mutation in [false, true]) {
      test('delayed A ${mutation ? 'POST' : 'GET'} 401 is not replayed as B',
          () async {
        session.restoreScript = () => BrowserSessionResult.success({
              'success': true,
              'data': {'token': sessionJwt('account-a')},
            });
        await api.restoreBrowserSessionForStart();
        final entered = Completer<void>();
        final response = Completer<http.Response>();
        var protectedCalls = 0;
        api.setHttpClient(MockClient((request) async {
          if (request.url.path.endsWith('/api/auth/login/email')) {
            return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'token': jwt('login-b'),
                    'user': {'id': 'acct-2'}
                  },
                }),
                200);
          }
          protectedCalls += 1;
          if (protectedCalls == 1) {
            entered.complete();
            return response.future;
          }
          return http.Response('{}', 200);
        }));
        session.issueScript = () => BrowserSessionResult.success({
              'success': true,
              'data': {
                'token': sessionJwt('account-b',
                    account: 'acct-2', family: 'family-b'),
              },
            });

        final Future<dynamic> pending = mutation
            ? api.createArtworkComment(artworkId: 'art-1', content: 'hello')
            : api.getMyProfile();
        await entered.future;
        await api.loginWithEmail(
            email: 'b@example.invalid', password: 'pw-pw-pw-pw');
        response.complete(http.Response('{"success":false}', 401));
        if (mutation) {
          await expectLater(pending, throwsA(anything));
        } else {
          expect((await pending)['success'], isFalse);
        }
        expect(protectedCalls, 1);
        expect(
          api.getAuthToken(),
          sessionJwt('account-b', account: 'acct-2', family: 'family-b'),
        );
      });
    }

    test('a refused restore ends the session instead of retrying forever',
        () async {
      session.restoreScript = () => BrowserSessionResult.success({
            'success': true,
            'data': {'token': sessionJwt('restored')},
          });
      await api.restoreBrowserSessionForStart();
      var calls = 0;
      api.setHttpClient(MockClient((_) async {
        calls += 1;
        return http.Response('{"success":false}', 401);
      }));
      session.restoreScript = () => BrowserSessionResult.failure(
          BrowserSessionOutcome.invalid,
          statusCode: 401);

      final profile = await api.getMyProfile();

      expect(profile['success'], isFalse);
      expect(calls, 1);
      expect(session.restoreCalls, 2);
      expect(api.getAuthToken(), isNull);
    });
  });

  Map<String, dynamic> bearerBodyFor(String token) => {
        'success': true,
        'data': {
          'token': token,
          'user': {'id': 'acct-2'},
        },
      };

  /// A tab holding the session-bound bearer [token], restored from the cookie.
  Future<void> startTabWithSession(String token) async {
    session.restoreScript = () => BrowserSessionResult.success({
          'success': true,
          'data': {
            'token': token,
            'user': {'id': 'acct-1'}
          },
        });
    expect(await api.restoreBrowserSessionForStart(), isTrue);
    expect(api.getAuthToken(), token);
  }

  group('cross-tab 401 recovery', () {
    final tabAToken = sessionJwt('a1', account: 'acct-1', family: 'family-a');
    final tabAReturnToken =
        sessionJwt('a2', account: 'acct-1', family: 'family-a');
    final tabBToken = sessionJwt('b1', account: 'acct-2', family: 'family-b');

    setUp(() {
      api.debugSetBrowserSessionWaitsForTesting(
        restore: const Duration(seconds: 2),
        operation: const Duration(seconds: 2),
      );
    });

    /// Tab B signs in elsewhere: the shared cookie now belongs to B's family and
    /// A's family is revoked. Only that cookie-level effect reaches tab A. Tab
    /// A's memory is untouched, exactly as with a second browser tab.
    void tabBSignsInElsewhere() {
      session.restoreScript = () => BrowserSessionResult.success({
            'success': true,
            'data': {
              'token': tabBToken,
              'user': {'id': 'acct-2'}
            },
          });
    }

    test(
        'a delayed A GET 401 after B signs in elsewhere is not replayed or adopted as B',
        () async {
      await startTabWithSession(tabAToken);
      final sent = <String>[];
      final entered = Completer<void>();
      final release = Completer<http.Response>();
      api.setHttpClient(MockClient((request) async {
        if (request.url.path != '/api/profiles/me') {
          return http.Response('{}', 200);
        }
        sent.add(request.headers['Authorization'] ?? '');
        if (sent.length == 1) {
          entered.complete();
          return release.future;
        }
        return http.Response('{"success":true,"data":{"id":"acct-2"}}', 200);
      }));

      final pending = api.getMyProfile();
      await entered.future;
      tabBSignsInElsewhere();
      release.complete(http.Response('{"success":false}', 401));
      final profile = await pending;

      expect(profile['success'], isFalse);
      expect(sent, ['Bearer $tabAToken']);
      expect(api.getAuthToken(), isNull);
      expect(api.browserSessionBearerActive, isFalse);
      expect(session.restoreCalls, 2);
    });

    test(
        'a delayed A POST 401 after B signs in elsewhere is never replayed as B',
        () async {
      await startTabWithSession(tabAToken);
      final sent = <String>[];
      final entered = Completer<void>();
      final release = Completer<http.Response>();
      api.setHttpClient(MockClient((request) async {
        if (request.method != 'POST') return http.Response('{}', 200);
        sent.add(request.headers['Authorization'] ?? '');
        if (sent.length == 1) {
          entered.complete();
          return release.future;
        }
        return http.Response('{"success":true,"data":{}}', 201);
      }));

      // likeArtwork is an authenticated POST marked idempotent, so it is the
      // replay-safe kind that may take the one recovery retry.
      final pending = api.likeArtwork('art-1');
      await entered.future;
      tabBSignsInElsewhere();
      release.complete(http.Response('{"success":false}', 401));
      await pending.catchError((Object _) => null);

      // The public-action fallback may send an unauthenticated request; no
      // request may carry B's bearer, and A's POST is not replayed with A.
      expect(sent.first, 'Bearer $tabAToken');
      expect(sent.where((h) => h.contains(tabBToken)), isEmpty);
      expect(sent.where((h) => h == 'Bearer $tabAToken'), hasLength(1));
      expect(api.getAuthToken(), isNull);
      expect(session.restoreCalls, 2);
    });

    test(
        'an expired A bearer restored after B signs in elsewhere is refused, not replaced by B',
        () async {
      api.setAuthTokenForTesting(
          expiredSessionJwt('a0', account: 'acct-1', family: 'family-a'));
      tabBSignsInElsewhere();
      final sent = <String>[];
      api.setHttpClient(MockClient((request) async {
        if (request.url.path != '/api/profiles/me') {
          return http.Response('{}', 200);
        }
        sent.add(request.headers['Authorization'] ?? '');
        return http.Response('{"success":false}', 401);
      }));

      final profile = await api.getMyProfile();

      expect(profile['success'], isFalse);
      expect(sent.any((h) => h.contains(tabBToken)), isFalse);
      expect(api.getAuthToken(), isNull);
      expect(session.restoreCalls, 1);
    });

    test('concurrent A 401s share one restore and both refuse B without replay',
        () async {
      await startTabWithSession(tabAToken);
      session.restoreGate = Completer<void>();
      final sent = <String>[];
      api.setHttpClient(MockClient((request) async {
        if (request.url.path != '/api/profiles/me') {
          return http.Response('{}', 200);
        }
        sent.add(request.headers['Authorization'] ?? '');
        return http.Response('{"success":false}', 401);
      }));

      final first = api.getMyProfile();
      final second = api.getMyProfile();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      tabBSignsInElsewhere();
      session.restoreGate!.complete();
      final results = await Future.wait([first, second]);

      expect(results.map((r) => r['success']), [false, false]);
      expect(sent, hasLength(2));
      expect(sent.any((h) => h.contains(tabBToken)), isFalse);
      expect(session.restoreCalls, 2);
      expect(api.getAuthToken(), isNull);
    });

    test(
        'same-family refresh serves concurrent A 401s with one restore and retries both',
        () async {
      await startTabWithSession(tabAToken);
      session.restoreGate = Completer<void>();
      session.restoreScript = () => BrowserSessionResult.success({
            'success': true,
            'data': {
              'token': tabAReturnToken,
              'user': {'id': 'acct-1'}
            },
          });
      final sent = <String>[];
      api.setHttpClient(MockClient((request) async {
        if (request.url.path != '/api/profiles/me') {
          return http.Response('{}', 200);
        }
        sent.add(request.headers['Authorization'] ?? '');
        if (sent.length <= 2) return http.Response('{"success":false}', 401);
        return http.Response('{"success":true,"data":{"id":"acct-1"}}', 200);
      }));

      final first = api.getMyProfile();
      final second = api.getMyProfile();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      session.restoreGate!.complete();
      final results = await Future.wait([first, second]);

      expect(results.map((r) => r['success']), [true, true]);
      expect(session.restoreCalls, 2);
      expect(api.getAuthToken(), tabAReturnToken);
      expect(sent.sublist(2), [
        'Bearer $tabAReturnToken',
        'Bearer $tabAReturnToken',
      ]);
    });

    test(
        'a restore that settles late after its wait never adopts, even when a sign-in follows',
        () async {
      api.debugSetBrowserSessionWaitsForTesting(
        restore: const Duration(milliseconds: 30),
        operation: const Duration(seconds: 2),
      );
      session.restoreGate = Completer<void>();
      session.restoreScript = () => BrowserSessionResult.success({
            'success': true,
            'data': {
              'token': tabAToken,
              'user': {'id': 'acct-1'}
            },
          });

      expect(await api.restoreBrowserSessionForStart(), isFalse);
      expect(api.browserSessionRestoreUnavailable, isTrue);

      serveEmailLogin(jwt('login-c'));
      session.issueScript = () => BrowserSessionResult.success({
            'success': true,
            'data': {
              'token': sessionJwt('c1', account: 'acct-3', family: 'family-c'),
              'user': {'id': 'acct-3'}
            },
          });
      final signIn = api.loginWithEmail(
        email: 'c@example.invalid',
        password: 'pw-pw-pw-pw',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      session.restoreGate!.complete();
      await signIn;

      expect(
        api.getAuthToken(),
        sessionJwt('c1', account: 'acct-3', family: 'family-c'),
      );
      expect(api.getAuthToken(), isNot(tabAToken));
      expect(session.restoreCalls, 1);
    });
  });

  group('bounded browser-session waits', () {
    setUp(() {
      api.debugSetBrowserSessionWaitsForTesting(
        restore: const Duration(milliseconds: 30),
        operation: const Duration(milliseconds: 30),
      );
    });

    test('a never-settling pending-logout revoke cannot hold startup',
        () async {
      SharedPreferences.setMockInitialValues({
        'browser_session_pending_logout_v1': true,
      });
      session.logoutGate = Completer<void>();

      final restored = await api
          .restoreBrowserSessionForStart()
          .timeout(const Duration(seconds: 2));

      expect(restored, isFalse);
      expect(api.browserSessionRestoreUnavailable, isTrue);
      expect(session.restoreCalls, 0);
      expect(api.getAuthToken(), isNull);
      session.logoutGate!.complete();
    });

    test('a never-settling startup restore settles unavailable and stays inert',
        () async {
      session.restoreGate = Completer<void>();
      session.restoreScript = () => BrowserSessionResult.success({
            'success': true,
            'data': {
              'token': jwt('late'),
              'user': {'id': 'acct-1'}
            },
          });

      expect(
        await api.restoreBrowserSessionForStart().timeout(
              const Duration(seconds: 2),
            ),
        isFalse,
      );
      expect(api.browserSessionRestoreUnavailable, isTrue);
      session.restoreGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(api.getAuthToken(), isNull);
      expect(session.restoreCalls, 1);
    });

    test(
        'a never-settling sign-in issue settles and its late session is revoked, not adopted',
        () async {
      serveEmailLogin(jwt('login-b'));
      session.issueGate = Completer<void>();

      await expectLater(
        api
            .loginWithEmail(
              email: 'b@example.invalid',
              password: 'pw-pw-pw-pw',
            )
            .timeout(const Duration(seconds: 2)),
        throwsA(isA<StateError>()),
      );
      expect(api.getAuthToken(), isNull);

      session.issueGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(api.getAuthToken(), isNull);
      expect(session.issueCalls, 1);
      expect(session.logoutCalls, 2);
    });

    test(
        'a never-settling sign-in revoke denies wallet sign-in within its bound',
        () async {
      session.logoutGate = Completer<void>();
      api.setHttpClient(MockClient((request) async {
        return http.Response(jsonEncode(bearerBodyFor(jwt('wallet'))), 200);
      }));

      await expectLater(
        api
            .loginWithWallet(
              walletAddress: 'wallet-1',
              signature: 'sig',
              message: 'msg',
            )
            .timeout(const Duration(seconds: 2)),
        throwsStateError,
      );
      expect(api.getAuthToken(), isNull);
      expect(session.issueCalls, 0);

      session.logoutGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(api.getAuthToken(), isNull);
    });

    test(
        'an unconfirmed sign-out reports false without claiming cancellation; the late confirmed revoke clears the marker',
        () async {
      SharedPreferences.setMockInitialValues({});
      session.logoutGate = Completer<void>();

      expect(
        await api
            .endBrowserSessionForLogout()
            .timeout(const Duration(seconds: 2)),
        isFalse,
      );
      expect(
        (await SharedPreferences.getInstance())
            .getBool('browser_session_pending_logout_v1'),
        isTrue,
      );
      expect(api.browserSessionLogoutUnresolved, isTrue);

      session.logoutGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        (await SharedPreferences.getInstance())
            .getBool('browser_session_pending_logout_v1'),
        isNull,
      );
      expect(api.browserSessionLogoutUnresolved, isFalse);
    });
  });

  group('logout intent durability', () {
    final tabAToken = sessionJwt('a1', account: 'acct-1', family: 'family-a');
    late FlakyIntentStore primary;
    late FlakyIntentStore fallback;

    setUp(() {
      api.debugSetBrowserSessionWaitsForTesting(
        restore: const Duration(seconds: 2),
        operation: const Duration(seconds: 2),
      );
      primary = FlakyIntentStore();
      fallback = FlakyIntentStore();
      api.debugSetBrowserSessionLogoutIntentStoresForTesting(
        primary: primary,
        fallback: fallback,
      );
    });

    test(
        'a failed shared marker write keeps the owed logout in the tab marker across a reload',
        () async {
      await startTabWithSession(tabAToken);
      primary.writesFail = true;
      session.logoutScript = () => const BrowserSessionResult.unavailable();

      expect(await api.endBrowserSessionForLogout(), isFalse);
      expect(api.browserSessionLogoutUnresolved, isTrue);
      expect(await fallback.readPendingLogout(), isTrue);
      await api.clearAuth();

      // Storage is readable again and the tab reloads; the server is back.
      primary.writesFail = false;
      session.logoutScript =
          () => BrowserSessionResult.success({'success': true});
      api.debugSimulateTabReloadForTesting();
      final restoresBefore = session.restoreCalls;

      expect(await api.restoreBrowserSessionForStart(), isFalse);
      expect(session.restoreCalls, restoresBefore);
      expect(api.getAuthToken(), isNull);
      expect(api.browserSessionLogoutUnresolved, isFalse);
      expect(await primary.readPendingLogout(), isFalse);
      expect(await fallback.readPendingLogout(), isFalse);
      await expectNoCredentialStorage(tabAToken);
    });

    test(
        'a logout intent no store accepts is unresolved and blocks restore until the write lands',
        () async {
      await startTabWithSession(tabAToken);
      primary.writesFail = true;
      fallback.writesFail = true;
      session.logoutScript = () => const BrowserSessionResult.unavailable();

      expect(await api.endBrowserSessionForLogout(), isFalse);
      expect(api.browserSessionLogoutUnresolved, isTrue);
      await api.clearAuth();
      final restoresBefore = session.restoreCalls;

      // Storage accepts writes again in this tab: the next restore decision
      // retries the write once, then refuses to restore while unconfirmed.
      primary.writesFail = false;
      expect(await api.restoreBrowserSessionForStart(), isFalse);
      expect(session.restoreCalls, restoresBefore);
      expect(await primary.readPendingLogout(), isTrue);
      expect(api.browserSessionLogoutUnresolved, isTrue);
      expect(api.getAuthToken(), isNull);

      // The server recovers; a reload sees the durable marker and revokes first.
      session.logoutScript =
          () => BrowserSessionResult.success({'success': true});
      api.debugSimulateTabReloadForTesting();

      expect(await api.restoreBrowserSessionForStart(), isFalse);
      expect(session.restoreCalls, restoresBefore);
      expect(await primary.readPendingLogout(), isFalse);
      expect(api.browserSessionLogoutUnresolved, isFalse);
    });

    test(
        'a late confirmed revoke of an older intent never clears a newer unconfirmed one',
        () async {
      api.debugSetBrowserSessionWaitsForTesting(
        restore: const Duration(seconds: 2),
        operation: const Duration(milliseconds: 30),
      );
      await startTabWithSession(tabAToken);
      session.logoutGate = Completer<void>();
      session.logoutScript = () => session.logoutCalls == 1
          ? BrowserSessionResult.success({'success': true})
          : const BrowserSessionResult.unavailable();

      final first = api.endBrowserSessionForLogout();
      expect(await first, isFalse);
      primary.writesFail = true;
      fallback.writesFail = true;
      final second = api.endBrowserSessionForLogout();
      expect(await second, isFalse);

      session.logoutGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(session.logoutCalls, 2);
      expect(await primary.readPendingLogout(), isTrue);
      expect(await fallback.readPendingLogout(), isTrue);
      expect(api.browserSessionLogoutUnresolved, isTrue);
    });

    test(
        'a stale tab marker never revokes a newer account signed in by another tab',
        () async {
      // Tab 1 signs out of account A; the server is down, so both the shared
      // marker and tab 1's own marker are written.
      await startTabWithSession(tabAToken);
      session.logoutScript = () => const BrowserSessionResult.unavailable();
      expect(await api.endBrowserSessionForLogout(), isFalse);
      expect(await primary.readPendingLogout(), isTrue);
      expect(await fallback.readPendingLogout(), isTrue);
      await api.clearAuth();

      // Tab 2 signs in as B: its confirmed logout clears the shared marker
      // (tab 2 has its own sessionStorage, so tab 1's marker stays) and B's
      // cookie is issued.
      expect(await primary.clear(), isTrue);
      final tabBToken = sessionJwt('b1', account: 'acct-2', family: 'family-b');
      session.restoreScript = () => BrowserSessionResult.success({
            'success': true,
            'data': {
              'token': tabBToken,
              'user': {'id': 'acct-2'}
            },
          });
      session.logoutScript =
          () => BrowserSessionResult.success({'success': true});

      // Tab 1 reloads with no bearer.
      api.debugSimulateTabReloadForTesting();
      final logoutsBefore = session.logoutCalls;

      await api.restoreBrowserSessionForStart();

      expect(session.logoutCalls, logoutsBefore,
          reason: 'the newer account cookie family must not be revoked');
      expect(await fallback.readPendingLogout(), isFalse);
      expect(await primary.readPendingLogout(), isFalse);
    });

    test(
        'a tab marker written while the shared write failed is still owed after a reload',
        () async {
      await startTabWithSession(tabAToken);
      primary.writesFail = true;
      session.logoutScript = () => const BrowserSessionResult.unavailable();
      expect(await api.endBrowserSessionForLogout(), isFalse);
      await api.clearAuth();

      primary.writesFail = false;
      session.logoutScript =
          () => BrowserSessionResult.success({'success': true});
      api.debugSimulateTabReloadForTesting();
      final logoutsBefore = session.logoutCalls;

      expect(await api.restoreBrowserSessionForStart(), isFalse);

      expect(session.logoutCalls, logoutsBefore + 1);
      expect(await fallback.readPendingLogout(), isFalse);
    });

    test('an unreadable shared marker keeps a shared-dependent tab marker',
        () async {
      await startTabWithSession(tabAToken);
      session.logoutScript = () => const BrowserSessionResult.unavailable();
      expect(await api.endBrowserSessionForLogout(), isFalse);
      await api.clearAuth();

      primary.readsFail = true;
      api.debugSimulateTabReloadForTesting();

      expect(await api.restoreBrowserSessionForStart(), isFalse);

      // Unreadable is never a verdict: the marker is neither cleared nor used
      // to authorize a restore.
      expect(await fallback.readPendingLogout(), isTrue);
      expect(api.browserSessionRestoreUnavailable, isTrue);
    });

    test('an unreadable marker never authorizes a restore', () async {
      primary.readsFail = true;

      expect(await api.restoreBrowserSessionForStart(), isFalse);

      expect(session.restoreCalls, 0);
      expect(api.getAuthToken(), isNull);
      expect(api.browserSessionRestoreUnavailable, isTrue);
    });
  });
}
