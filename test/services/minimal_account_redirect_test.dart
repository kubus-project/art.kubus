import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _newAccountPayload() => <String, dynamic>{
      'data': <String, dynamic>{
        'user': <String, dynamic>{'id': 'user-1'},
        'isNewUser': true,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a pending action does not bypass role/profile onboarding', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: _newAccountPayload(),
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      userId: 'user-1',
      redirectRoute: '/a/artwork-1',
    );

    expect(result.state, PostAuthRouteState.onboardingRequired);
    expect(result.routeName, '/onboarding');
    expect(result.onboardingStepId, 'role');
  });

  test('a pending action does not clear account-scoped onboarding state',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final scopeKey = OnboardingStateService.buildAuthOnboardingScopeKey(
      userId: 'user-1',
    );
    await OnboardingStateService.markAuthOnboardingPending(
      prefs: prefs,
      scopeKey: scopeKey,
    );

    await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: _newAccountPayload(),
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      userId: 'user-1',
    );

    expect(
      OnboardingStateService.hasPendingAuthOnboardingSync(
        prefs,
        scopeKey: scopeKey,
      ),
      isTrue,
    );
  });

  test('returning wallet sign-in remains a ready account', () async {
    final prefs = await SharedPreferences.getInstance();
    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'id': 'user-2'},
        },
      },
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      walletAddress: 'So11111111111111111111111111111111111111112',
      userId: 'user-2',
      redirectRoute: '/map',
      origin: AuthOrigin.wallet,
    );

    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/map');
  });
}
