import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:flutter/material.dart';

import '../screens/desktop/onboarding/desktop_onboarding_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';

/// Session-scoped onboarding deferral.
///
/// When a signed-out user opens the app via a deep link on a first launch,
/// we let them view the deep-linked content first and defer onboarding until
/// a later user-driven navigation.
class DeferredOnboardingProvider extends ChangeNotifier {
  bool _enabledForSession = false;
  bool _initialDeepLinkHandled = false;
  bool _presentedThisSession = false;

  bool get enabledForSession => _enabledForSession;
  bool get initialDeepLinkHandled => _initialDeepLinkHandled;

  void enableForDeepLinkColdStart() {
    if (_enabledForSession) return;
    _enabledForSession = true;
    _initialDeepLinkHandled = false;
    _presentedThisSession = false;
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

    _presentedThisSession = true;
    // Clear the deferral state immediately so subsequent attempts won't re-trigger.
    // (Onboarding completion persists via OnboardingStateService, not this provider.)
    reset(keepPresentedFlag: true);

    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => isDesktop ? const DesktopOnboardingScreen() : const OnboardingScreen(),
        settings: RouteSettings(name: isDesktop ? '/onboarding/desktop' : '/onboarding'),
      ),
    );
    return true;
  }

  /// Clears the deferral state for the current session.
  void reset({bool keepPresentedFlag = false}) {
    if (!_enabledForSession && !_initialDeepLinkHandled) return;
    _enabledForSession = false;
    _initialDeepLinkHandled = false;
    if (!keepPresentedFlag) {
      _presentedThisSession = false;
    }
    notifyListeners();
  }
}
