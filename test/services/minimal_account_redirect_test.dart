import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A backend payload for a brand-new account with no wallet — the exact shape
/// that used to force the visitor into role, profile and wallet setup.
Map<String, dynamic> _newAccountPayload() => <String, dynamic>{
      'data': <String, dynamic>{
        'user': <String, dynamic>{'id': 'user-1'},
        'isNewUser': true,
        'requiresWalletSetup': true,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  const controller = AuthRedirectController();

  test('a visitor finishing an action lands back on the exact entity',
      () async {
    final result = await controller.resolvePostAuthRedirect(
      prefs: prefs,
      payload: _newAccountPayload(),
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      userId: 'user-1',
      redirectRoute: '/m/marker-9',
      origin: AuthOrigin.google,
      requiresWalletSetup: true,
      minimalAccount: true,
    );

    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/m/marker-9');
    expect(result.onboardingStepId, isNull);
  });

  test('minimal account skips role, profile, wallet and DAO setup', () async {
    // Same payload without minimalAccount would route into structured
    // onboarding; this is the regression guard for that.
    final gated = await controller.resolvePostAuthRedirect(
      prefs: prefs,
      payload: _newAccountPayload(),
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      userId: 'user-1',
      redirectRoute: '/a/artwork-1',
      origin: AuthOrigin.emailPassword,
      requiresWalletSetup: true,
    );
    expect(gated.state, PostAuthRouteState.onboardingRequired);
    expect(gated.routeName, '/onboarding');

    final minimal = await controller.resolvePostAuthRedirect(
      prefs: prefs,
      payload: _newAccountPayload(),
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      userId: 'user-1',
      redirectRoute: '/a/artwork-1',
      origin: AuthOrigin.emailPassword,
      requiresWalletSetup: true,
      minimalAccount: true,
    );
    expect(minimal.state, PostAuthRouteState.ready);
    expect(minimal.routeName, '/a/artwork-1');
  });

  test('minimal account clears the pending-onboarding marker', () async {
    final scopeKey = OnboardingStateService.buildAuthOnboardingScopeKey(
      userId: 'user-1',
    );
    await OnboardingStateService.markAuthOnboardingPending(
      prefs: prefs,
      scopeKey: scopeKey,
    );
    expect(
      OnboardingStateService.hasPendingAuthOnboardingSync(
        prefs,
        scopeKey: scopeKey,
      ),
      isTrue,
    );

    await controller.resolvePostAuthRedirect(
      prefs: prefs,
      payload: _newAccountPayload(),
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      userId: 'user-1',
      redirectRoute: '/a/artwork-1',
      origin: AuthOrigin.google,
      minimalAccount: true,
    );

    // Otherwise the next cold start would re-impose the flow we just skipped.
    expect(
      OnboardingStateService.hasPendingAuthOnboardingSync(
        prefs,
        scopeKey: scopeKey,
      ),
      isFalse,
    );
  });

  test('minimal account falls back to /main with no return route', () async {
    final result = await controller.resolvePostAuthRedirect(
      prefs: prefs,
      payload: _newAccountPayload(),
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      userId: 'user-1',
      origin: AuthOrigin.google,
      minimalAccount: true,
    );

    expect(result.routeName, '/main');
  });

  test('normal registration still gets full onboarding', () async {
    final result = await controller.resolvePostAuthRedirect(
      prefs: prefs,
      payload: _newAccountPayload(),
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      userId: 'user-1',
      origin: AuthOrigin.emailPassword,
      requiresWalletSetup: true,
    );

    expect(result.state, PostAuthRouteState.onboardingRequired);
    expect(result.onboardingStepId, isNotNull);
  });

  test('a returning wallet sign-in is unaffected', () async {
    final result = await controller.resolvePostAuthRedirect(
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
