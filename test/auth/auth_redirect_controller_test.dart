import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('existing Google user routes to main without onboarding', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: <String, dynamic>{
        'user': <String, dynamic>{'id': 'user-1'},
      },
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      walletAddress: 'wallet-1',
      userId: 'user-1',
    );

    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/main');
    expect(result.onboardingStepId, isNull);
  });

  test('new Google user routes to structured onboarding, not password setup',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: <String, dynamic>{
        'isNewUser': true,
        'authProvider': 'google',
      },
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      walletAddress: 'wallet-2',
      userId: 'user-2',
    );

    expect(result.state, PostAuthRouteState.onboardingRequired);
    expect(result.routeName, '/onboarding');
    expect(result.onboardingStepId, 'role');
    expect(result.routeName, isNot(contains('password')));
  });

  test('existing email user routes to requested redirect', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: <String, dynamic>{},
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      redirectRoute: '/wallet',
      redirectArguments: <String, Object>{'tab': 'security'},
    );

    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/wallet');
    expect(result.arguments, <String, Object>{'tab': 'security'});
  });

  test('restored session uses same ready route path', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: <String, dynamic>{},
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      walletAddress: 'wallet-restored',
      userId: 'user-restored',
    );

    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/main');
  });
}
