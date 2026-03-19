import 'package:art_kubus/services/auth_onboarding_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<SharedPreferences> seedProgress({
    required Set<String> completedSteps,
    Set<String> deferredSteps = const <String>{},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: AuthOnboardingService.onboardingFlowVersion,
      completedSteps: completedSteps,
      deferredSteps: deferredSteps,
    );
    return prefs;
  }

  test('defaults new authenticated accounts to role when profile is not ready',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final state = await AuthOnboardingService.resolveStructuredOnboardingResume(
      prefs: prefs,
      hasPendingAuthOnboarding: false,
      hasAuthenticatedSession: true,
      hasHydratedProfile: false,
      requiresWalletBackup: false,
      heuristicNextStepId: null,
      persona: null,
      payload: const <String, dynamic>{
        'data': <String, dynamic>{'isNewUser': true},
      },
    );

    expect(state.requiresStructuredOnboarding, isTrue);
    expect(state.nextStepId, 'role');
  });

  test('resumes creator onboarding at dao review after role and profile',
      () async {
    final prefs = await seedProgress(
      completedSteps: <String>{'account', 'role', 'profile'},
    );
    final state = await AuthOnboardingService.resolveStructuredOnboardingResume(
      prefs: prefs,
      hasPendingAuthOnboarding: true,
      hasAuthenticatedSession: true,
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      heuristicNextStepId: null,
      persona: 'creator',
    );

    expect(state.requiresStructuredOnboarding, isTrue);
    expect(state.nextStepId, 'daoReview');
  });

  test('resumes lover onboarding at account permissions after profile',
      () async {
    final prefs = await seedProgress(
      completedSteps: <String>{'account', 'role', 'profile'},
    );
    final state = await AuthOnboardingService.resolveStructuredOnboardingResume(
      prefs: prefs,
      hasPendingAuthOnboarding: true,
      hasAuthenticatedSession: true,
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      heuristicNextStepId: null,
      persona: 'lover',
    );

    expect(state.requiresStructuredOnboarding, isTrue);
    expect(state.nextStepId, 'accountPermissions');
  });

  test('does not require resume when account flow is already complete',
      () async {
    final prefs = await seedProgress(
      completedSteps: AuthOnboardingService.accountStepIds.toSet(),
    );
    final state = await AuthOnboardingService.resolveStructuredOnboardingResume(
      prefs: prefs,
      hasPendingAuthOnboarding: true,
      hasAuthenticatedSession: true,
      hasHydratedProfile: true,
      requiresWalletBackup: false,
      heuristicNextStepId: null,
      persona: 'creator',
    );

    expect(state.requiresStructuredOnboarding, isFalse);
    expect(state.nextStepId, isNull);
  });

  test('resumes at wallet backup when backup is still required', () async {
    final prefs = await seedProgress(
      completedSteps: <String>{'account', 'role', 'profile'},
    );
    final state = await AuthOnboardingService.resolveStructuredOnboardingResume(
      prefs: prefs,
      hasPendingAuthOnboarding: true,
      hasAuthenticatedSession: true,
      hasHydratedProfile: true,
      requiresWalletBackup: true,
      heuristicNextStepId: null,
      persona: 'lover',
    );

    expect(state.requiresStructuredOnboarding, isTrue);
    expect(state.nextStepId, 'walletBackup');
  });
}
