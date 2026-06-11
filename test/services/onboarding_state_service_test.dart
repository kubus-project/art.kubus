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

  test('REGRESSION: migrates unscoped progress when scoped exists but is empty',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final unsccopedCompletedSteps = <String>{'account', 'role'};
    final unscopedDeferredSteps = <String>{'profile'};

    // Create an explicit scoped entry with the correct version but EMPTY steps.
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      completedSteps: const <String>{},
      deferredSteps: const <String>{},
      flowScopeKey: testScopeKey,
    );

    // Save unscoped progress (non-empty)
    await OnboardingStateService.saveFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      completedSteps: unsccopedCompletedSteps,
      deferredSteps: unscopedDeferredSteps,
      flowScopeKey: null,
    );

    // Load with scope - should detect scoped is empty and migrate unscoped into scoped
    final progress = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      flowScopeKey: testScopeKey,
    );

    expect(progress.completedSteps, equals(unsccopedCompletedSteps));
    expect(progress.deferredSteps, equals(unscopedDeferredSteps));

    // Verify scoped keys now contain migrated data
    final migrated = await OnboardingStateService.loadFlowProgress(
      prefs: prefs,
      onboardingVersion: testVersion,
      flowScopeKey: testScopeKey,
    );
    expect(migrated.completedSteps, equals(unsccopedCompletedSteps));
  });

  test('REGRESSION: prefers scoped progress over unscoped when both exist',
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

  test('REGRESSION: does not migrate empty unscoped progress to scoped keys',
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

  test('REGRESSION: unscoped progress migration respects version mismatch',
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

  test('Google onboarding registration guard is active before timeout',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 1, 1, 12);
    await prefs.setBool(
      OnboardingStateService.onboardingGoogleRegistrationInProgressKey,
      true,
    );
    await prefs.setInt(
      OnboardingStateService.onboardingGoogleRegistrationStartedAtKey,
      now.subtract(const Duration(minutes: 9)).millisecondsSinceEpoch,
    );

    expect(
      OnboardingStateService.hasActiveGoogleOnboardingRegistrationGuardSync(
        prefs,
        now: now,
      ),
      isTrue,
    );
  });

  test('Google onboarding registration guard expires after timeout', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 1, 1, 12);
    await prefs.setBool(
      OnboardingStateService.onboardingGoogleRegistrationInProgressKey,
      true,
    );
    await prefs.setInt(
      OnboardingStateService.onboardingGoogleRegistrationStartedAtKey,
      now.subtract(const Duration(minutes: 11)).millisecondsSinceEpoch,
    );

    expect(
      OnboardingStateService.hasActiveGoogleOnboardingRegistrationGuardSync(
        prefs,
        now: now,
      ),
      isFalse,
    );
  });

  test('account-link guard records the user id and is active before timeout',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await OnboardingStateService.markAccountLinkStarted(
      prefs: prefs,
      userId: 'user-google-42',
    );

    expect(
      OnboardingStateService.hasActiveAccountLinkGuardSync(prefs),
      isTrue,
    );
    expect(
      OnboardingStateService.accountLinkGuardUserIdSync(prefs),
      'user-google-42',
    );
  });

  test('account-link guard expires after timeout', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 1, 1, 12);
    await prefs.setBool(
      OnboardingStateService.onboardingAccountLinkInProgressKey,
      true,
    );
    await prefs.setInt(
      OnboardingStateService.onboardingAccountLinkStartedAtKey,
      now.subtract(const Duration(minutes: 11)).millisecondsSinceEpoch,
    );

    expect(
      OnboardingStateService.hasActiveAccountLinkGuardSync(prefs, now: now),
      isFalse,
    );
  });

  test('clearing the account-link guard removes all guard keys', () async {
    final prefs = await SharedPreferences.getInstance();
    await OnboardingStateService.markAccountLinkStarted(
      prefs: prefs,
      userId: 'user-google-42',
    );
    await OnboardingStateService.clearAccountLinkGuard(prefs: prefs);

    expect(
      OnboardingStateService.hasActiveAccountLinkGuardSync(prefs),
      isFalse,
    );
    expect(OnboardingStateService.accountLinkGuardUserIdSync(prefs), isNull);
    expect(
      prefs.getInt(OnboardingStateService.onboardingAccountLinkStartedAtKey),
      isNull,
    );
  });
}
