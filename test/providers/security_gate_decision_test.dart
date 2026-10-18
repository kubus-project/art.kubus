import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:flutter/widgets.dart';
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

/// Lets a test make the settings read fail on demand.
class _FlakySettingsGate extends SecurityGateProvider {
  _FlakySettingsGate() : super(promptCooldown: Duration.zero);

  bool failReloads = false;

  @override
  Future<void> reloadSettings() async {
    if (failReloads) throw StateError('settings read failed');
    await super.reloadSettings();
  }
}

const _tsKey = 'last_inactive_ts';

int _agoMs(Duration d) => DateTime.now().subtract(d).millisecondsSinceEpoch;

_FlakySettingsGate _gate({
  Map<String, Object> prefs = const {},
  _Wallet? wallet,
}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'jwt_token': 'stored-token',
    'requirePin': true,
    'autoLockSeconds': 60,
    ...prefs,
  });
  final gate = _FlakySettingsGate();
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
}
