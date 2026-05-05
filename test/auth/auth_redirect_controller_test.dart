import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/auth_onboarding_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
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

  test('existing creator wallet user routes to main without dao review',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PreferenceKeys.hasCompletedOnboarding, false);

    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: const <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'id': 'creator-1'},
        },
      },
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      walletAddress: 'wallet-creator',
      userId: 'creator-1',
      heuristicNextStepId: 'daoReview',
      persona: 'creator',
      origin: AuthOrigin.wallet,
    );

    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/main');
    expect(result.onboardingStepId, isNull);
  });

  test('existing institution wallet user routes to main without dao review',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PreferenceKeys.hasCompletedOnboarding, false);

    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: const <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'id': 'institution-1'},
        },
      },
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      walletAddress: 'wallet-institution',
      userId: 'institution-1',
      heuristicNextStepId: 'daoReview',
      persona: 'institution',
      origin: AuthOrigin.wallet,
    );

    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/main');
    expect(result.onboardingStepId, isNull);
  });

  test('new creator wallet user can enter dao review onboarding', () async {
    final prefs = await SharedPreferences.getInstance();

    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: const <String, dynamic>{'isNewUser': true},
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      walletAddress: 'wallet-new-creator',
      userId: 'new-creator',
      persona: 'creator',
      origin: AuthOrigin.wallet,
    );

    expect(result.state, PostAuthRouteState.onboardingRequired);
    expect(result.onboardingStepId, 'daoReview');
  });

  test('pending scoped dao review still resumes for matching wallet', () async {
    final prefs = await SharedPreferences.getInstance();
    const wallet = 'wallet-pending';
    final scope = OnboardingStateService.buildAuthOnboardingScopeKey(
      walletAddress: wallet,
      userId: 'user-pending',
    );
    await OnboardingStateService.markAuthOnboardingPending(
      prefs: prefs,
      scopeKey: scope,
    );
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: AuthOnboardingService.onboardingFlowVersion,
      completedSteps: <String>{'account', 'role', 'profile'},
      deferredSteps: const <String>{},
      flowScopeKey: scope,
    );

    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: const <String, dynamic>{},
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      walletAddress: wallet,
      userId: 'user-pending',
      heuristicNextStepId: 'daoReview',
      persona: 'creator',
      origin: AuthOrigin.wallet,
    );

    expect(result.state, PostAuthRouteState.onboardingRequired);
    expect(result.onboardingStepId, 'daoReview');
  });

  test('pending onboarding for wallet A does not affect wallet B', () async {
    final prefs = await SharedPreferences.getInstance();
    final walletAScope = OnboardingStateService.buildAuthOnboardingScopeKey(
      walletAddress: 'wallet-a',
      userId: 'user-a',
    );
    await OnboardingStateService.markAuthOnboardingPending(
      prefs: prefs,
      scopeKey: walletAScope,
    );

    final result = await const AuthRedirectController().resolvePostAuthRedirect(
      prefs: prefs,
      payload: const <String, dynamic>{},
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      walletAddress: 'wallet-b',
      userId: 'user-b',
      heuristicNextStepId: 'daoReview',
      persona: 'creator',
      origin: AuthOrigin.wallet,
    );

    expect(result.state, PostAuthRouteState.ready);
    expect(result.routeName, '/main');
  });
}
