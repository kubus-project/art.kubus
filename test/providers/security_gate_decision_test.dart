import 'dart:async';

import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wallet extends WalletProvider {
  _Wallet({this.pinThrows = false}) : super(deferInit: true);

  final bool pinThrows;

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> hasPinOrThrow() async {
    if (pinThrows) throw StateError('pin store unavailable');
    return true;
  }

  @override
  Future<bool> canUseBiometrics() async => false;
}

/// Lets a test make the settings read fail or hang on demand.
class _FlakySettingsGate extends SecurityGateProvider {
  _FlakySettingsGate({required Duration timeout})
      : super(promptCooldown: Duration.zero, lockDecisionTimeout: timeout);

  bool failReloads = false;
  int reloadCalls = 0;

  /// Each queued completer makes the next reload hang until completed.
  final List<Completer<void>> hangOn = <Completer<void>>[];

  @override
  Future<void> reloadSettings() async {
    reloadCalls++;
    if (failReloads) throw StateError('settings read failed');
    if (hangOn.isNotEmpty) return hangOn.removeAt(0).future;
    await super.reloadSettings();
  }
}

const _tsKey = 'last_inactive_ts';

int _agoMs(Duration d) => DateTime.now().subtract(d).millisecondsSinceEpoch;

_FlakySettingsGate _gate({
  Map<String, Object> prefs = const {},
  _Wallet? wallet,
  Duration timeout = const Duration(seconds: 5),
}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'jwt_token': 'stored-token',
    'requirePin': true,
    'autoLockSeconds': 60,
    ...prefs,
  });
  final gate = _FlakySettingsGate(timeout: timeout);
  gate.bindDependencies(
    profileProvider: ProfileProvider(),
    walletProvider: wallet ?? _Wallet(),
    notificationProvider: NotificationProvider(),
  );
  return gate;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lock decision pending', () {
    test('is pending right after construction and clears after initialize',
        () async {
      final gate = _gate(prefs: {'requirePin': false});
      expect(gate.isLockDecisionPending, isTrue);
      await gate.initialize();
      expect(gate.isLockDecisionPending, isFalse);
      expect(gate.isLocked, isFalse);
    });

    test('is set synchronously on resumed and clears after the decision',
        () async {
      final gate = _gate(prefs: {_tsKey: _agoMs(const Duration(seconds: 5))});
      await gate.initialize();
      expect(gate.isLockDecisionPending, isFalse);

      gate.onAppLifecycleChanged(AppLifecycleState.resumed);
      expect(gate.isLockDecisionPending, isTrue);

      await gate.lifecycleIdleForTesting;
      expect(gate.isLockDecisionPending, isFalse);
      expect(gate.isLocked, isFalse);
    });

    test('Require PIN off clears pending without locking', () async {
      final gate = _gate(prefs: {'requirePin': false});
      await gate.initialize();
      expect(gate.isLockDecisionPending, isFalse);
      expect(gate.isLocked, isFalse);
    });
  });

  group('failures fail closed', () {
    test('reloadSettings throwing on resume with last-known PIN on locks',
        () async {
      final gate = _gate(prefs: {_tsKey: _agoMs(const Duration(seconds: 5))});
      await gate.initialize();
      expect(gate.isLocked, isFalse);

      gate.failReloads = true;
      gate.onAppLifecycleChanged(AppLifecycleState.resumed);
      await gate.lifecycleIdleForTesting;

      expect(gate.isLocked, isTrue);
      expect(gate.isLockDecisionPending, isFalse);
    });

    test('biometrics-only lock still locks when the resume read fails',
        () async {
      final gate = _gate(prefs: {
        'requirePin': false,
        'biometricAuth': true,
        _tsKey: _agoMs(const Duration(seconds: 5)),
      });
      await gate.initialize();
      expect(gate.isLocked, isFalse);

      gate.failReloads = true;
      gate.onAppLifecycleChanged(AppLifecycleState.resumed);
      await gate.lifecycleIdleForTesting;

      expect(gate.isLocked, isTrue);
      expect(gate.isLockDecisionPending, isFalse);
    });

    test('cold start with settings read throwing and a PIN present locks',
        () async {
      final gate = _gate();
      gate.failReloads = true;
      await gate.initialize();

      expect(gate.isLocked, isTrue);
      expect(gate.isLockDecisionPending, isFalse);
    });

    test('a PIN store that throws still locks on cold-start failure', () async {
      final gate = _gate(wallet: _Wallet(pinThrows: true));
      gate.failReloads = true;
      await gate.initialize();

      expect(gate.isLocked, isTrue);
      expect(gate.isLockDecisionPending, isFalse);
    });
  });

  group('lock decisions are bounded', () {
    const timeout = Duration(seconds: 5);

    test('hung settings read on cold start clears pending and locks', () {
      fakeAsync((async) {
        final gate = _gate(timeout: timeout);
        gate.hangOn.add(Completer<void>());
        var done = false;
        gate.initialize().then((_) => done = true);

        expect(gate.isLockDecisionPending, isTrue);
        async.elapse(timeout);
        async.flushMicrotasks();

        expect(done, isTrue);
        expect(gate.isLockDecisionPending, isFalse);
        expect(gate.isLocked, isTrue);
      });
    });

    test('hung decision on resume clears pending and the chain advances', () {
      fakeAsync((async) {
        final gate = _gate(timeout: timeout);
        gate.initialize();
        async.flushMicrotasks();
        expect(gate.isLockDecisionPending, isFalse);
        final callsAfterColdStart = gate.reloadCalls;

        gate.hangOn.add(Completer<void>());
        gate.onAppLifecycleChanged(AppLifecycleState.resumed);
        gate.onAppLifecycleChanged(AppLifecycleState.resumed);
        expect(gate.isLockDecisionPending, isTrue);

        async.elapse(timeout);
        async.flushMicrotasks();

        // The first resume timed out; the second, queued behind it, ran.
        expect(gate.reloadCalls, callsAfterColdStart + 2);
        expect(gate.isLockDecisionPending, isFalse);
        expect(gate.isLocked, isTrue);
      });
    });

    test(
        'an orphan finishing late neither goes negative nor clears a newer '
        'decision', () {
      fakeAsync((async) {
        final gate = _gate(timeout: timeout);
        gate.initialize();
        async.flushMicrotasks();

        final orphan = Completer<void>();
        final newer = Completer<void>();
        gate.hangOn.add(orphan);
        gate.onAppLifecycleChanged(AppLifecycleState.resumed);
        async.elapse(timeout);
        async.flushMicrotasks();
        expect(gate.isLockDecisionPending, isFalse);

        gate.hangOn.add(newer);
        gate.onAppLifecycleChanged(AppLifecycleState.resumed);
        expect(gate.isLockDecisionPending, isTrue);

        // The orphan finishes while the newer decision is still running.
        orphan.complete();
        async.flushMicrotasks();
        expect(gate.isLockDecisionPending, isTrue);

        newer.complete();
        async.flushMicrotasks();
        expect(gate.isLockDecisionPending, isFalse);
      });
    });
  });
}
