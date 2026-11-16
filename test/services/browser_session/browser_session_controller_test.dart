import 'dart:async';

import 'package:art_kubus/services/browser_session/browser_session_api.dart';
import 'package:art_kubus/services/browser_session/browser_session_controller.dart';
import 'package:art_kubus/services/browser_session/browser_session_lock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scripted [BrowserSessionApi]: counts calls and can hold a restore open.
class FakeBrowserSessionApi implements BrowserSessionApi {
  int issueCalls = 0;
  int restoreCalls = 0;
  int logoutCalls = 0;
  String? lastLoginToken;
  BrowserSessionResult Function()? restoreScript;
  Completer<void>? restoreGate;
  bool issueThrows = false;

  static final BrowserSessionResult issued = BrowserSessionResult.success(
    {
      'success': true,
      'data': {'token': 'session-bearer'},
    },
  );

  @override
  Future<BrowserSessionResult> issue({required String loginToken}) async {
    issueCalls += 1;
    lastLoginToken = loginToken;
    if (issueThrows) throw StateError('synthetic issue failure');
    return issued;
  }

  @override
  Future<BrowserSessionResult> restore() async {
    restoreCalls += 1;
    final gate = restoreGate;
    if (gate != null) await gate.future;
    final script = restoreScript;
    return script == null
        ? BrowserSessionResult.success({
            'success': true,
            'data': {'token': 'restored-bearer'},
          })
        : script();
  }

  @override
  Future<BrowserSessionResult> logout() async {
    logoutCalls += 1;
    return BrowserSessionResult.success(
        {'success': true, 'message': 'Signed out'});
  }
}

/// Records how many bodies ran inside the lock at once.
class SpyLock implements BrowserSessionLock {
  final InProcessBrowserSessionLock _inner = InProcessBrowserSessionLock();
  int active = 0;
  int maxActive = 0;
  int runs = 0;

  @override
  Future<T> run<T>(Future<T> Function() body) {
    runs += 1;
    return _inner.run(() async {
      active += 1;
      if (active > maxActive) maxActive = active;
      try {
        return await body();
      } finally {
        active -= 1;
      }
    });
  }
}

void main() {
  group('restore', () {
    test('overlapping callers share one in-flight restore', () async {
      final api = FakeBrowserSessionApi()..restoreGate = Completer<void>();
      final controller = BrowserSessionController(
        api: api,
        lock: InProcessBrowserSessionLock(),
      );

      final first = controller.restore();
      final second = controller.restore();
      expect(identical(first, second), isTrue);

      api.restoreGate!.complete();
      final results = await Future.wait([first, second]);

      expect(api.restoreCalls, 1);
      expect(results.every((r) => r.isSuccess), isTrue);
    });

    test('a restore after the previous one settled starts a new call',
        () async {
      final api = FakeBrowserSessionApi();
      final controller = BrowserSessionController(
        api: api,
        lock: InProcessBrowserSessionLock(),
      );

      await controller.restore();
      await controller.restore();

      expect(api.restoreCalls, 2);
    });

    test('every restore runs inside the cross-tab lock', () async {
      final api = FakeBrowserSessionApi();
      final lock = SpyLock();
      final controller = BrowserSessionController(api: api, lock: lock);

      await controller.restore();

      expect(lock.runs, 1);
      expect(lock.maxActive, 1);
    });

    test('a restore that throws settles as unavailable, never as a throw',
        () async {
      final api = FakeBrowserSessionApi()
        ..restoreScript = () => throw StateError('synthetic');
      final controller = BrowserSessionController(
        api: api,
        lock: InProcessBrowserSessionLock(),
      );

      final result = await controller.restore();

      expect(result.outcome, BrowserSessionOutcome.unavailable);
    });
  });

  group('issue and logout', () {
    test('issue forwards the login token and never throws', () async {
      final api = FakeBrowserSessionApi();
      final controller = BrowserSessionController(
        api: api,
        lock: InProcessBrowserSessionLock(),
      );

      final ok = await controller.issue(loginToken: 'login-token');
      expect(ok.isSuccess, isTrue);
      expect(api.lastLoginToken, 'login-token');

      api.issueThrows = true;
      final failed = await controller.issue(loginToken: 'login-token');
      expect(failed.outcome, BrowserSessionOutcome.unavailable);
    });

    test('logout reaches the API once', () async {
      final api = FakeBrowserSessionApi();
      final controller = BrowserSessionController(
        api: api,
        lock: InProcessBrowserSessionLock(),
      );

      final result = await controller.logout();

      expect(result.isSuccess, isTrue);
      expect(api.logoutCalls, 1);
    });
  });
}
