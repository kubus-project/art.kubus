import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:flutter/material.dart';

import '../models/onboarding_completion_navigation.dart';
import '../models/protected_action_requirements.dart';
import '../screens/onboarding/onboarding_flow_screen.dart';

/// Holds one specific, already-started account journey so it can be resumed
/// the next time an anonymous visitor attempts an identity-required action.
///
/// This is the only thing it does. Ordinary navigation never opens onboarding:
/// a visitor can browse, open public entities, switch tabs and come back to the
/// map without any account surface replacing the app. The structured journey
/// appears only when the visitor has genuinely begun one (for example an email
/// verification that was left pending) and then tries something that needs an
/// identity.
/// Builds the resumed journey. Injectable so tests can observe exactly what the
/// visitor is sent to without constructing the whole onboarding screen.
typedef ResumedOnboardingBuilder = Widget Function({
  required bool forceDesktop,
  required String initialStepId,
  required String completionRoute,
  required Object? completionArguments,
  required ProtectedActionRequirements requirements,
  required bool requiresWalletSetup,
  required OnboardingCompletionNavigation completionNavigation,
});

Widget _defaultResumedOnboarding({
  required bool forceDesktop,
  required String initialStepId,
  required String completionRoute,
  required Object? completionArguments,
  required ProtectedActionRequirements requirements,
  required bool requiresWalletSetup,
  required OnboardingCompletionNavigation completionNavigation,
}) =>
    OnboardingFlowScreen(
      forceDesktop: forceDesktop,
      initialStepId: initialStepId,
      completionRoute: completionRoute,
      completionArguments: completionArguments,
      requirements: requirements,
      requiresWalletSetup: requiresWalletSetup,
      completionNavigation: completionNavigation,
    );

class DeferredOnboardingProvider extends ChangeNotifier {
  DeferredOnboardingProvider({
    ResumedOnboardingBuilder onboardingBuilder = _defaultResumedOnboarding,
  }) : _onboardingBuilder = onboardingBuilder;

  final ResumedOnboardingBuilder _onboardingBuilder;
  bool _enabledForSession = false;
  bool _presentedThisSession = false;
  String? _initialStepId;
  String? _completionRoute;
  ProtectedActionRequirements _requirements =
      ProtectedActionRequirements.accountOnly;

  bool get enabledForSession => _enabledForSession;
  String? get initialStepId => _initialStepId;
  String? get completionRoute => _completionRoute;
  ProtectedActionRequirements get requirements => _requirements;

  /// Arms the resume for [initialStepId]. Idempotent for the session.
  ///
  /// [requirements] is the scope the interrupted journey was started for; the
  /// resumed flow stays inside it (an account journey ends at the account).
  void enableForProtectedAction({
    String initialStepId = 'account',
    String completionRoute = '/map',
    ProtectedActionRequirements requirements =
        ProtectedActionRequirements.accountOnly,
  }) {
    final normalizedStep = initialStepId.trim();
    final normalizedRoute = completionRoute.trim();
    if (_enabledForSession) {
      var changed = false;
      if (_initialStepId == null && normalizedStep.isNotEmpty) {
        _initialStepId = normalizedStep;
        changed = true;
      }
      if (_completionRoute == null && normalizedRoute.isNotEmpty) {
        _completionRoute = normalizedRoute;
        changed = true;
      }
      if (changed) notifyListeners();
      return;
    }

    _enabledForSession = true;
    _presentedThisSession = false;
    _initialStepId = normalizedStep.isEmpty ? 'account' : normalizedStep;
    _completionRoute = normalizedRoute.isEmpty ? '/map' : normalizedRoute;
    _requirements = requirements;
    notifyListeners();
  }

  /// Resumes the armed journey exactly once, when an anonymous visitor first
  /// attempts an identity-required action.
  ///
  /// The caller has already captured the attempted action, so the journey is
  /// pushed *above* the screen the visitor is on and completes back to
  /// [returnRoute]/[returnArguments] (the exact origin), never to the shell
  /// route stored when it was armed and never by replacing the current route.
  /// The resumed scope is the wider of the interrupted journey's and the
  /// attempted action's [requirements], so neither is dropped.
  ///
  /// Returns true if onboarding navigation was triggered and the caller should
  /// stop (the action is resumed from inside the journey).
  bool maybeShowOnboardingForProtectedAction(
    BuildContext context, {
    required String returnRoute,
    Map<String, String> returnArguments = const <String, String>{},
    ProtectedActionRequirements requirements =
        ProtectedActionRequirements.accountOnly,
  }) {
    if (!_enabledForSession || _presentedThisSession) return false;

    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final navigator = Navigator.of(context);
    final initialStepId = _initialStepId ?? 'account';
    final scope =
        ProtectedActionRequirements.merge(_requirements, requirements);

    _presentedThisSession = true;
    reset(keepPresentedFlag: true);

    navigator.push(
      MaterialPageRoute(
        builder: (_) => _onboardingBuilder(
          forceDesktop: isDesktop,
          initialStepId: initialStepId,
          completionRoute: returnRoute,
          completionArguments: returnArguments.isEmpty ? null : returnArguments,
          requirements: scope,
          requiresWalletSetup: scope.requiresWallet,
          completionNavigation: OnboardingCompletionNavigation.returnToOrigin,
        ),
        settings: const RouteSettings(name: '/onboarding'),
      ),
    );
    return true;
  }

  /// Clears the deferral state for the current session.
  void reset({bool keepPresentedFlag = false}) {
    if (!_enabledForSession) return;
    _enabledForSession = false;
    _initialStepId = null;
    _completionRoute = null;
    _requirements = ProtectedActionRequirements.accountOnly;
    if (!keepPresentedFlag) {
      _presentedThisSession = false;
    }
    notifyListeners();
  }
}
