import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/services/auth_session_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': 'stored-token',
      'requirePin': true,
    });
  });

  test('SecurityGateProvider coalesces concurrent auth failures', () async {
    final gate = SecurityGateProvider(promptCooldown: Duration.zero);

    final f1 = gate.handleAuthFailure(
      const AuthFailureContext(
        statusCode: 401,
        method: 'GET',
        path: '/api/test',
      ),
    );
    final f2 = gate.handleAuthFailure(
      const AuthFailureContext(
        statusCode: 401,
        method: 'GET',
        path: '/api/test',
      ),
    );

    await Future<void>.delayed(Duration.zero);
    expect(gate.isResolving, isTrue);
    gate.reset();

    final r1 = await f1;
    final r2 = await f2;
    expect(r1.outcome, AuthReauthOutcome.cancelled);
    expect(r2.outcome, AuthReauthOutcome.cancelled);
    expect(gate.isResolving, isFalse);
    expect(gate.isLocked, isFalse);
  });

  test('SecurityGateProvider does not prompt reauth on cold start wallet-only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': 'wallet-only',
      'has_wallet': true,
    });

    final gate = SecurityGateProvider(promptCooldown: Duration.zero);
    final result = await gate.handleAuthFailure(
      const AuthFailureContext(
        statusCode: 401,
        method: 'GET',
        path: '/api/profiles/me',
      ),
    );

    expect(result.outcome, AuthReauthOutcome.notEnabled);
    expect(gate.isResolving, isFalse);
    expect(gate.isLocked, isFalse);
  });
}
