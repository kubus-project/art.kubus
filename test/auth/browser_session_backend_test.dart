import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/browser_session/browser_session_api.dart';
import 'package:art_kubus/services/browser_session/browser_session_controller.dart';
import 'package:art_kubus/services/browser_session/browser_session_lock.dart';
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

/// Scripted browser-session API: every outcome is set by the test.
class ScriptedSessionApi implements BrowserSessionApi {
  int issueCalls = 0;
  int restoreCalls = 0;
  int logoutCalls = 0;
  String? lastLoginToken;
  Completer<void>? restoreGate;

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
    return BrowserSessionResult.success({'success': true});
  }
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

    test('a start restore that outlives its timeout settles to guest',
        () async {
      session.restoreGate = Completer<void>();

      final restored = await api.restoreBrowserSessionForStart(
          timeout: const Duration(milliseconds: 20));

      expect(restored, isFalse);
      expect(api.getAuthToken(), isNull);
      // The late restore completes in the background; let it settle so it
      // cannot leak a bearer into the next test.
      session.restoreGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(api.getAuthToken(), jwt('restored'));
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
      session.restoreScript = () => BrowserSessionResult.failure(
          BrowserSessionOutcome.unavailable,
          statusCode: 503);

      await api.endBrowserSessionForLogout();
      await api.clearAuth();

      expect(api.getAuthToken(), isNull);
    });
  });

  group('401 from the normal API', () {
    test('one restore then one retry with the restored bearer', () async {
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
          expect(request.headers['Authorization'], 'Bearer ${jwt('restored')}');
          return http.Response('{"success":false}', 401);
        }
        expect(request.headers['Authorization'], 'Bearer ${jwt('rotated')}');
        return http.Response('{"success":true,"data":{"id":"acct-1"}}', 200);
      }));
      session.restoreScript = () => BrowserSessionResult.success({
            'success': true,
            'data': {'token': jwt('rotated')},
          });

      final profile = await api.getMyProfile();

      expect(profile['success'], isTrue, reason: '$seen');
      expect(calls, 2, reason: '$seen');
      expect(session.restoreCalls, 2);
      expect(api.getAuthToken(), jwt('rotated'));
    });

    test('a refused restore ends the session instead of retrying forever',
        () async {
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
}
