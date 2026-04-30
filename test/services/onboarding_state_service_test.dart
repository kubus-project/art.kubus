import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const int testVersion = 5;
  const String testScopeKey = 'wallet:test-wallet-1';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads scoped progress when it exists for the version', () async {
    final prefs = await SharedPreferences.getInstance();
    final completedSteps = <String>{'account', 'role'};
    final deferredSteps = <String>{'profile'};

    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      completedSteps: completedSteps,
      deferredSteps: deferredSteps,
      flowScopeKey: testScopeKey,
    );

    final progress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      flowScopeKey: testScopeKey,
    );

    expect(progress.completedSteps, equals(completedSteps));
    expect(progress.deferredSteps, equals(deferredSteps));
  });

  test('returns empty progress when version mismatch', () async {
    final prefs = await SharedPreferences.getInstance();
    final completedSteps = <String>{'account', 'role'};

    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      completedSteps: completedSteps,
      deferredSteps: const <String>{},
      flowScopeKey: testScopeKey,
    );

    // Try to load with different version
    final progress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion + 1,
      flowScopeKey: testScopeKey,
    );

    expect(progress.completedSteps, isEmpty);
    expect(progress.deferredSteps, isEmpty);
    expect(progress.lastSeenVersion, equals(testVersion + 1));
  });

  // Regression tests for progress migration

  test(
      'REGRESSION: migrates unscoped progress to scoped keys when scoped is empty',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final unsccopedCompletedSteps = <String>{'account', 'role'};
    final unscopedDeferredSteps = <String>{'profile'};

    // Save unscoped progress first (simulating initial registration)
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      completedSteps: unsccopedCompletedSteps,
      deferredSteps: unscopedDeferredSteps,
      flowScopeKey: null,
    );

    // Now load with a scope key (simulating after sign-in when scope is determined)
    final progress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      flowScopeKey: testScopeKey,
    );

    // Should return unscoped progress
    expect(progress.completedSteps, equals(unsccopedCompletedSteps));
    expect(progress.deferredSteps, equals(unscopedDeferredSteps));

    // Verify that scoped keys now have the migrated data
    final migratedProgress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      flowScopeKey: testScopeKey,
    );
    expect(migratedProgress.completedSteps, equals(unsccopedCompletedSteps));
  });

  test(
      'REGRESSION: prefers scoped progress over unscoped when both exist',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final unsccopedCompletedSteps = <String>{'account'};
    final scopedCompletedSteps = <String>{'account', 'role', 'profile'};

    // Save unscoped progress
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      completedSteps: unsccopedCompletedSteps,
      deferredSteps: const <String>{},
      flowScopeKey: null,
    );

    // Save scoped progress (newer/more advanced)
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      completedSteps: scopedCompletedSteps,
      deferredSteps: const <String>{},
      flowScopeKey: testScopeKey,
    );

    // Load with scope - should get scoped, not unscoped
    final progress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      flowScopeKey: testScopeKey,
    );

    expect(progress.completedSteps, equals(scopedCompletedSteps));
  });

  test(
      'REGRESSION: does not migrate empty unscoped progress to scoped keys',
      () async {
    final prefs = await SharedPreferences.getInstance();

    // Save empty unscoped progress (version exists but no steps)
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      completedSteps: const <String>{},
      deferredSteps: const <String>{},
      flowScopeKey: null,
    );

    // Try to load with a scope
    final progress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      flowScopeKey: testScopeKey,
    );

    // Should return empty (no migration of empty progress)
    expect(progress.completedSteps, isEmpty);
    expect(progress.deferredSteps, isEmpty);

    // Verify scoped keys were NOT created
    final scopedVersionKey = 'onboarding_version:$testScopeKey';
    expect(prefs.containsKey(scopedVersionKey), isFalse);
  });

  test(
      'REGRESSION: unscoped progress migration respects version mismatch',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final unsccopedCompletedSteps = <String>{'account'};

    // Save unscoped progress with old version
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion - 1,
      completedSteps: unsccopedCompletedSteps,
      deferredSteps: const <String>{},
      flowScopeKey: null,
    );

    // Load with new version and scope - should NOT migrate old version
    final progress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      flowScopeKey: testScopeKey,
    );

    // Should be empty because unscoped version doesn't match
    expect(progress.completedSteps, isEmpty);
    expect(progress.deferredSteps, isEmpty);
  });
}
