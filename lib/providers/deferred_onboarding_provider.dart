import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:flutter/material.dart';

import '../screens/onboarding/onboarding_flow_screen.dart';

/// Session-scoped onboarding deferral.
///
/// When a signed-out user opens the app via a deep link on a first launch,
/// we let them view the deep-linked content first and defer onboarding until
/// a later user-driven navigation.
class DeferredOnboardingProvider extends ChangeNotifier {
  bool _enabledForSession = false;
  bool _initialDeepLinkHandled = false;
  bool _presentedThisSession = false;
  String? _initialStepId;

  bool get enabledForSession => _enabledForSession;
  bool get initialDeepLinkHandled => _initialDeepLinkHandled;
  String? get initialStepId => _initialStepId;

  void enableForDeepLinkColdStart({String? initialStepId}) {
    final normalizedStep = (initialStepId ?? '').trim();
    if (_enabledForSession) {
      if (_initialStepId == null && normalizedStep.isNotEmpty) {
        _initialStepId = normalizedStep;
        notifyListeners();
      }
      return;
    }
    _enabledForSession = true;
    _initialDeepLinkHandled = false;
    _presentedThisSession = false;
    _initialStepId = normalizedStep.isEmpty ? null : normalizedStep;
    notifyListeners();
  }

  void markInitialDeepLinkHandled() {
    if (!_enabledForSession) return;
    if (_initialDeepLinkHandled) return;
    _initialDeepLinkHandled = true;
    notifyListeners();
  }

  /// If onboarding was deferred due to a deep-link cold start, this opens the
  /// onboarding flow exactly once per session.
  ///
  /// Returns true if onboarding navigation was triggered and the caller should
  /// stop any further navigation (e.g. tab switching).
  bool maybeShowOnboarding(BuildContext context) {
    if (!_enabledForSession) return false;

    // Only prompt after the initial deep-linked content has been opened.
    if (!_initialDeepLinkHandled) return false;

    // Guard against repeated prompts due to rebuilds or multiple navigation attempts.
    if (_presentedThisSession) return false;

    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final navigator = Navigator.of(context);
    final initialStepId = _initialStepId;

    _presentedThisSession = true;
    // Clear the deferral state immediately so subsequent attempts won't re-trigger.
    // (Onboarding completion persists via OnboardingStateService, not this provider.)
    reset(keepPresentedFlag: true);

    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnboardingFlowScreen(
          forceDesktop: isDesktop,
          initialStepId: initialStepId,
        ),
        settings: const RouteSettings(name: '/onboarding'),
      ),
    );
    return true;
  }

  /// Clears the deferral state for the current session.
  void reset({bool keepPresentedFlag = false}) {
    if (!_enabledForSession && !_initialDeepLinkHandled) return;
    _enabledForSession = false;
    _initialDeepLinkHandled = false;
    _initialStepId = null;
    if (!keepPresentedFlag) {
      _presentedThisSession = false;
    }
    notifyListeners();
  }
}
