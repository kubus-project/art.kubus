import 'package:art_kubus/providers/deferred_onboarding_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deep-link deferral retains the onboarding continuation step', () {
    final provider = DeferredOnboardingProvider();

    provider.enableForDeepLinkColdStart(initialStepId: 'walletConnect');
    provider.markInitialDeepLinkHandled();

    expect(provider.enabledForSession, isTrue);
    expect(provider.initialDeepLinkHandled, isTrue);
    expect(provider.initialStepId, 'walletConnect');
  });

  test('later onboarding context can enrich an existing deferral', () {
    final provider = DeferredOnboardingProvider();

    provider.enableForDeepLinkColdStart();
    provider.enableForDeepLinkColdStart(initialStepId: 'account');

    expect(provider.initialStepId, 'account');
  });
}
