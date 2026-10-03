import 'dart:io';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/core/app_initializer_helper.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Degraded startup (initialisation threw, or the 20s watchdog fired) has no
/// session to derive an account scope from. It must still find an interrupted
/// journey that was recorded under a user/wallet scope, and otherwise land in
/// public discovery.
void main() {
  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  final base = PreferenceKeys.pendingAuthOnboarding;

  test('no pending journey opens public discovery', () async {
    final prefs = await prefsWith(<String, Object>{});

    final decision = decideDegradedStartup(prefs);

    expect(decision.route, StartupRouteType.none);
  });

  test('an unscoped pending journey resumes at the account step', () async {
    final prefs = await prefsWith(<String, Object>{base: true});

    final decision = decideDegradedStartup(prefs);

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'account');
  });

  test('a user-scoped pending journey is found', () async {
    final prefs = await prefsWith(<String, Object>{});
    await OnboardingStateService.markAuthOnboardingPending(
      prefs: prefs,
      scopeKey: 'user:user-1',
    );

    // markAuthOnboardingPending removes the unscoped key when a scope exists.
    expect(prefs.getBool(base), isNull);
    expect(prefs.getBool('$base:user:user-1'), isTrue);

    final decision = decideDegradedStartup(prefs);

    expect(decision.route, StartupRouteType.onboarding);
  });

  test('a wallet-scoped pending journey is found', () async {
    final prefs = await prefsWith(<String, Object>{});
    await OnboardingStateService.markAuthOnboardingPending(
      prefs: prefs,
      scopeKey: 'wallet:abc123',
    );

    final decision = decideDegradedStartup(prefs);

    expect(decision.route, StartupRouteType.onboarding);
  });

  test('a pending email verification resumes at verifyEmail', () async {
    final prefs = await prefsWith(<String, Object>{
      '$base:user:user-1': true,
      'onboarding_pending_email_verification_v1': true,
      'onboarding_verification_email_v3': 'visitor@example.com',
    });

    final decision = decideDegradedStartup(prefs);

    expect(decision.route, StartupRouteType.onboarding);
    expect(decision.onboardingInitialStepId, 'verifyEmail');
  });

  group('stale markers are ignored', () {
    test('a scoped key that was cleared to false', () async {
      final prefs = await prefsWith(<String, Object>{
        '$base:user:user-1': false,
        '$base:wallet:abc': false,
      });

      expect(decideDegradedStartup(prefs).route, StartupRouteType.none);
    });

    test('a non-boolean value under a pending key', () async {
      final prefs = await prefsWith(<String, Object>{
        base: 'true',
        '$base:user:user-1': 1,
      });

      expect(decideDegradedStartup(prefs).route, StartupRouteType.none);
    });

    test('an unrelated key that merely shares the prefix text', () async {
      final prefs = await prefsWith(<String, Object>{
        '${base}_other': true,
        'x$base': true,
      });

      expect(decideDegradedStartup(prefs).route, StartupRouteType.none);
    });

    test('clearing the journey leaves nothing to resume', () async {
      final prefs = await prefsWith(<String, Object>{});
      await OnboardingStateService.markAuthOnboardingPending(
        prefs: prefs,
        scopeKey: 'user:user-1',
      );
      await OnboardingStateService.clearPendingAuthOnboarding(prefs: prefs);

      expect(decideDegradedStartup(prefs).route, StartupRouteType.none);
    });
  });

  test('the capability scope helper agrees with the pending-journey lookup',
      () async {
    final prefs = await prefsWith(<String, Object>{
      OnboardingStateService.capabilityScopeKey: 'participant',
    });
    // A scope with no open journey is not reported.
    expect(OnboardingStateService.capabilityScopeSync(prefs), isNull);

    await OnboardingStateService.markAuthOnboardingPending(
      prefs: prefs,
      scopeKey: 'wallet:abc',
    );
    expect(
        OnboardingStateService.hasAnyPendingAuthOnboardingSync(prefs), isTrue);
    expect(OnboardingStateService.capabilityScopeSync(prefs), 'participant');
  });

  test('both degraded paths (init failure and watchdog) share one decision',
      () {
    final source = File('lib/core/app_initializer.dart').readAsStringSync();

    expect(source, contains('decideDegradedStartup(prefs)'));
    // Exactly one place decides, and both entry points go through it.
    expect(RegExp('decideDegradedStartup\\(').allMatches(source).length, 1);
    expect(
      RegExp('_openDegradedEntry\\(navigator\\)').allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(source, isNot(contains('hasPendingAuthOnboardingSync(prefs),\n')));
  });
}
