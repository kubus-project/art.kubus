import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> hasPinOrThrow() async => true;

  @override
  Future<bool> canUseBiometrics() async => false;
}

const _tsKey = 'last_inactive_ts';

/// The app lock must hold across a process restart and across the ordinary
/// background -> foreground transition.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int agoMs(Duration d) => DateTime.now().subtract(d).millisecondsSinceEpoch;

  Future<SecurityGateProvider> buildGate(
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': 'stored-token',
      'requirePin': true,
      'autoLockSeconds': 60,
      ...prefs,
    });
    final gate = SecurityGateProvider(promptCooldown: Duration.zero);
    gate.bindDependencies(
      profileProvider: ProfileProvider(),
      walletProvider: _Wallet(),
      notificationProvider: NotificationProvider(),
    );
    return gate;
  }

  group('cold start', () {
    test('locks when no background timestamp was persisted', () async {
      final gate = await buildGate(const {});
      await gate.initialize();
      expect(gate.isLocked, isTrue);
      expect(gate.lockReason, SecurityLockReason.autoLock);
    });

    test('locks when the persisted timestamp is older than the threshold',
        () async {
      final gate =
          await buildGate({_tsKey: agoMs(const Duration(minutes: 10))});
      await gate.initialize();
      expect(gate.isLocked, isTrue);
    });

    test('stays open when the app was left only briefly', () async {
      final gate = await buildGate({_tsKey: agoMs(const Duration(seconds: 5))});
      await gate.initialize();
      expect(gate.isLocked, isFalse);
    });

    test('locks when the persisted timestamp lies in the future', () async {
      final gate = await buildGate({
        _tsKey:
            DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
      });
      await gate.initialize();
      expect(gate.isLocked, isTrue);
    });

    test('locks when the setting is "immediately"', () async {
      final gate = await buildGate({
        'autoLockSeconds': -1,
        _tsKey: agoMs(const Duration(seconds: 1)),
      });
      await gate.initialize();
      expect(gate.isLocked, isTrue);
    });

    test('does not lock when auto-lock is "never"', () async {
      final gate = await buildGate({'autoLockSeconds': 0});
      await gate.initialize();
      expect(gate.isLocked, isFalse);
    });

    test('does not lock when no lock is configured', () async {
      final gate = await buildGate({'requirePin': false});
      await gate.initialize();
      expect(gate.isLocked, isFalse);
    });
  });

  group('returning to the foreground', () {
    Future<void> returnToForeground(SecurityGateProvider gate) async {
      // Flutter delivers this sequence when the app comes back.
      gate.onAppLifecycleChanged(AppLifecycleState.hidden);
      gate.onAppLifecycleChanged(AppLifecycleState.inactive);
      gate.onAppLifecycleChanged(AppLifecycleState.resumed);
      await gate.lifecycleIdleForTesting;
    }

    test('locks after a long absence even though inactive precedes resumed',
        () async {
      final gate =
          await buildGate({_tsKey: agoMs(const Duration(minutes: 10))});
      await gate.reloadSettings();
      await returnToForeground(gate);
      expect(gate.isLocked, isTrue);
    });

    test('stays open after a short absence', () async {
      final gate = await buildGate({_tsKey: agoMs(const Duration(seconds: 5))});
      await gate.reloadSettings();
      await returnToForeground(gate);
      expect(gate.isLocked, isFalse);
    });

    test('records the departure on hidden/paused, not on inactive', () async {
      final gate = await buildGate(const {});
      await gate.reloadSettings();

      gate.onAppLifecycleChanged(AppLifecycleState.inactive);
      await gate.lifecycleIdleForTesting;
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_tsKey), isNull);

      gate.onAppLifecycleChanged(AppLifecycleState.hidden);
      await gate.lifecycleIdleForTesting;
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_tsKey), isNotNull);
    });

    test('a later hidden event does not move the recorded departure', () async {
      final departed = agoMs(const Duration(minutes: 3));
      final gate = await buildGate({_tsKey: departed});
      await gate.reloadSettings();

      gate.onAppLifecycleChanged(AppLifecycleState.hidden);
      await gate.lifecycleIdleForTesting;
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_tsKey), departed);
    });
  });
}
