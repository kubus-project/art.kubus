import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import 'profile_provider.dart';
import '../services/account_identity.dart';
import '../services/telemetry/telemetry_service.dart';

/// Decides when to offer an unauthenticated visitor a non-blocking reason to
/// create an account.
///
/// The strongest activation trigger is an attempted Save or Follow, which the
/// contextual gate already handles. This covers the visitor who browses a lot
/// but never taps a protected action: after several meaningful entity views we
/// surface a dismissible card once, and then stay quiet.
///
/// Deliberate constraints, so exploration is never damaged:
/// * never for an authenticated visitor,
/// * never on landing — it takes [viewsBeforePrompt] entity views to arm,
/// * at most once per session and once per [promptInterval],
/// * dismissible, and dismissal is remembered.
class ActivationPromptProvider extends ChangeNotifier {
  ActivationPromptProvider({TelemetryService? telemetry})
      : _telemetry = telemetry ?? TelemetryService() {
    AccountIdentity.addListener(_handleAccountIdentityChanged);
  }

  static const String lastShownPrefsKey =
      'kubus_activation_prompt_last_shown_v1';

  /// Meaningful entity views required before the prompt is offered.
  static const int viewsBeforePrompt = 3;

  /// Minimum gap between prompts across sessions.
  static const Duration promptInterval = Duration(hours: 24);

  /// Reported with the prompt events so the trigger can be evaluated later.
  static const String triggerName = 'entity_views';

  final TelemetryService _telemetry;

  // The owner of "who is signed in": the prompt is for visitors without an
  // account, so it asks the owner. Nothing here reads the credential.
  ProfileProvider? _identityOwner;

  /// Hands in the owner (the provider tree does so on every owner change) and
  /// follows it, so a sign-in takes the prompt off screen at once.
  void bindIdentityOwner(ProfileProvider owner) {
    if (identical(_identityOwner, owner)) return;
    _identityOwner?.removeListener(notifyListeners);
    _identityOwner = owner..addListener(notifyListeners);
  }

  int _entityViews = 0;
  bool _armed = false;
  bool _resolvedThisSession = false;
  bool _intervalChecked = false;
  bool _intervalAllows = true;

  // The account the pending state belongs to. The canonical account key, not a
  // profile id: a wallet disconnect or a token refresh of the same account keeps
  // the state.
  String _heldAccountKey = AccountIdentity.accountKey;

  int get entityViews => _entityViews;

  /// True when the prompt should currently be on screen.
  bool get shouldPrompt =>
      AppConfig.isFeatureEnabled('activationPrompt') &&
      _armed &&
      !_resolvedThisSession &&
      !(_identityOwner?.isSignedIn ?? false);

  /// Records a meaningful entity view from a screen that may be rendered
  /// outside the app's provider tree (embedded shells, widget tests).
  ///
  /// A missing provider means "no prompt here", never a crash: detail screens
  /// are public content and must render for anyone.
  static void recordEntityViewFor(BuildContext context) {
    try {
      unawaited(context.read<ActivationPromptProvider>().recordEntityView());
    } catch (_) {
      // No provider in scope; nothing to count.
    }
  }

  /// Records a meaningful entity view (artwork, event, exhibition,
  /// institution or a marker overlay opened on the map).
  Future<void> recordEntityView() async {
    if (!AppConfig.isFeatureEnabled('activationPrompt')) return;
    if (_resolvedThisSession || (_identityOwner?.isSignedIn ?? false)) return;

    _entityViews += 1;
    if (_entityViews < viewsBeforePrompt || _armed) return;

    if (!_intervalChecked) {
      _intervalChecked = true;
      _intervalAllows = await _intervalElapsed();
    }
    if (!_intervalAllows) {
      _resolvedThisSession = true;
      return;
    }

    _armed = true;
    notifyListeners();
  }

  /// Called by the prompt when it first becomes visible.
  void markPresented() {
    unawaited(_telemetry.trackActivationPromptViewed(trigger: triggerName));
    unawaited(_recordShownAt());
  }

  Future<void> dismiss() async {
    if (_resolvedThisSession && !_armed) return;
    _armed = false;
    _resolvedThisSession = true;
    unawaited(_telemetry.trackActivationPromptDismissed(trigger: triggerName));
    await _recordShownAt();
    notifyListeners();
  }

  Future<void> accept() async {
    _armed = false;
    _resolvedThisSession = true;
    unawaited(_telemetry.trackActivationPromptAccepted(trigger: triggerName));
    await _recordShownAt();
    notifyListeners();
  }

  /// Clears the session counters, e.g. once the visitor has an account.
  void reset() {
    if (_entityViews == 0 && !_armed && !_resolvedThisSession) return;
    _entityViews = 0;
    _armed = false;
    _resolvedThisSession = false;
    notifyListeners();
  }

  /// A pending prompt belongs to one session. An account switch or sign-out
  /// ends that session, so its pending prompt and view count go with it. A
  /// same-account change (a token refresh, a wallet link or disconnect) keeps
  /// them. A sign-out always clears, even when the held key is a guest's: a
  /// guest sign-in announces nothing, so the held key may not name the account.
  void _handleAccountIdentityChanged() {
    final key = AccountIdentity.accountKey;
    final sameAccount = key.isNotEmpty && key == _heldAccountKey;
    _heldAccountKey = key;
    if (sameAccount) return;
    reset();
  }

  @override
  void dispose() {
    AccountIdentity.removeListener(_handleAccountIdentityChanged);
    _identityOwner?.removeListener(notifyListeners);
    super.dispose();
  }

  Future<bool> _intervalElapsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getInt(lastShownPrefsKey);
      if (raw == null) return true;
      final lastShown = DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
      return DateTime.now().toUtc().difference(lastShown) >= promptInterval;
    } catch (_) {
      // If we cannot tell when it was last shown, stay quiet rather than risk
      // prompting a visitor repeatedly.
      return false;
    }
  }

  Future<void> _recordShownAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        lastShownPrefsKey,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Best effort only.
    }
  }
}
