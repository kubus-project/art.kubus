import 'package:art_kubus/models/protected_action_requirements.dart';
import 'package:art_kubus/providers/deferred_onboarding_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeferredOnboardingProvider (protected-action resume only)', () {
    test('is idle until a journey is explicitly armed', () {
      final provider = DeferredOnboardingProvider();

      expect(provider.enabledForSession, isFalse);
      expect(provider.initialStepId, isNull);
      expect(provider.completionRoute, isNull);
    });

    test('arming records the step, return route and account-only scope', () {
      final provider = DeferredOnboardingProvider();

      provider.enableForProtectedAction(
        initialStepId: 'account',
        completionRoute: '/map',
      );

      expect(provider.enabledForSession, isTrue);
      expect(provider.initialStepId, 'account');
      expect(provider.completionRoute, '/map');
      expect(provider.requirements, ProtectedActionRequirements.accountOnly);
    });

    test('keeps the capability scope the journey was started for', () {
      final provider = DeferredOnboardingProvider();

      provider.enableForProtectedAction(
        initialStepId: 'walletConnect',
        requirements: ProtectedActionRequirements.wallet,
      );

      expect(provider.initialStepId, 'walletConnect');
      expect(provider.requirements, ProtectedActionRequirements.wallet);
    });

    test('arming twice is idempotent and never widens the scope', () {
      final provider = DeferredOnboardingProvider();

      provider.enableForProtectedAction(initialStepId: 'verifyEmail');
      provider.enableForProtectedAction(
        initialStepId: 'account',
        requirements: ProtectedActionRequirements.wallet,
      );

      expect(provider.initialStepId, 'verifyEmail');
      expect(provider.requirements, ProtectedActionRequirements.accountOnly);
    });

    test('reset clears the armed journey', () {
      final provider = DeferredOnboardingProvider();

      provider.enableForProtectedAction();
      provider.reset();

      expect(provider.enabledForSession, isFalse);
      expect(provider.initialStepId, isNull);
      expect(provider.completionRoute, isNull);
      expect(provider.requirements, ProtectedActionRequirements.accountOnly);
    });

    testWidgets('an idle provider never navigates on ordinary use',
        (tester) async {
      final provider = DeferredOnboardingProvider();
      var shown = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              shown = provider.maybeShowOnboardingForProtectedAction(
                context,
                returnRoute: '/map',
              );
              return const Scaffold(body: Text('public discovery'));
            },
          ),
        ),
      );

      expect(shown, isFalse);
      expect(find.text('public discovery'), findsOneWidget);
    });
  });
}
