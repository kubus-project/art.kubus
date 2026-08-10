import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/config.dart';
import '../guest_session_service.dart';
import 'contribution_type.dart';
import 'kubus_client_context.dart';
import 'telemetry_config.dart';
import 'telemetry_event.dart';
import 'telemetry_event_queue.dart';
import 'telemetry_sender.dart';
import 'telemetry_uuid.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;

  TelemetryService._internal()
      : _queue = SharedPreferencesTelemetryEventQueue(),
        _sender = BackendTelemetrySender();

  final TelemetryEventQueue _queue;
  final TelemetrySender _sender;

  bool _initialized = false;
  Future<void>? _initializationFuture;
  bool _analyticsPreferenceEnabled = true;
  bool _enabled = false;
  bool? _enabledByBuildFlagOverride;

  String? _actorUserId;
  late String _sessionId;
  DateTime _sessionStartUtc = DateTime.now().toUtc();
  String? _locale;

  String _flowStage = 'main';

  String _screenName = 'unknown';
  String? _screenRoute;
  DateTime? _screenEnteredAtUtc;

  Timer? _flushTimer;
  DateTime? _flushScheduledForUtc;
  bool _flushing = false;
  int _consecutiveFailures = 0;
  Timer? _backoffTimer;
  final Random _rand = Random.secure();

  final Set<String> _onceKeys = <String>{};

  // First-touch campaign attribution is independent of guest mode and is
  // attached to every event so both direct registration and map discovery can
  // be tied to later account and contribution milestones.
  Map<String, Object?> _entryAttribution = const <String, Object?>{};

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  String? get currentSessionId {
    if (!_initialized || !_enabled) return null;
    final value = _sessionId.trim();
    if (!_uuidRegex.hasMatch(value)) return null;
    return value;
  }

  @visibleForTesting
  static TelemetryService createForTest({
    required TelemetryEventQueue queue,
    required TelemetrySender sender,
    bool analyticsEnabledByBuildFlag = true,
    bool analyticsPreferenceEnabled = true,
  }) {
    final svc = TelemetryService._test(queue: queue, sender: sender);
    svc._enabledByBuildFlagOverride = analyticsEnabledByBuildFlag;
    svc._analyticsPreferenceEnabled = analyticsPreferenceEnabled;
    svc._enabled = analyticsEnabledByBuildFlag && analyticsPreferenceEnabled;
    KubusClientContext.instance.setEnabled(svc._enabled);
    return svc;
  }

  TelemetryService._test({
    required TelemetryEventQueue queue,
    required TelemetrySender sender,
  })  : _queue = queue,
        _sender = sender;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    final inFlight = _initializationFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final initialization = _initialize();
    _initializationFuture = initialization;
    try {
      await initialization;
    } finally {
      if (!_initialized) _initializationFuture = null;
    }
  }

  Future<void> _initialize() async {
    _sessionId = TelemetryUuid.v4();
    _sessionStartUtc = DateTime.now().toUtc();

    try {
      // Initial-route dispatch may already be persisting a mobile deep link.
      // Wait before snapshotting metadata so initial route events share it.
      await GuestSessionService.waitForLaunchAttributionCapture();
      final prefs = await SharedPreferences.getInstance();
      _analyticsPreferenceEnabled = prefs.getBool('enableAnalytics') ?? true;
      _actorUserId = _normalizeUuid(prefs.getString('user_id'));
      // Age out an acquisition touch that has passed its window before reading
      // it, so an old campaign cannot attach itself to this session's events.
      await GuestSessionService.pruneExpiredAttribution(prefs: prefs);
      _entryAttribution = _loadEntryAttribution(prefs);
      _restoreSession(prefs);
    } catch (_) {
      _analyticsPreferenceEnabled = true;
      _actorUserId = null;
      _entryAttribution = const <String, Object?>{};
    }

    _enabled = (_enabledByBuildFlagOverride ??
            AppTelemetryConfig.enabledByBuildFlag) &&
        _analyticsPreferenceEnabled;
    KubusClientContext.instance.setEnabled(_enabled);

    await _queue.init();
    _initialized = true;

    if (_enabled) {
      _syncClientContext();
      _scheduleFlush(AppTelemetryConfig.flushOnEnqueueDelay);
    }
  }

  void setAnalyticsPreferenceEnabled(bool enabled) {
    _analyticsPreferenceEnabled = enabled;
    _enabled = (_enabledByBuildFlagOverride ??
            AppTelemetryConfig.enabledByBuildFlag) &&
        _analyticsPreferenceEnabled;
    KubusClientContext.instance.setEnabled(_enabled);
    if (!_initialized) return;
    if (_enabled) {
      _syncClientContext();
      _scheduleFlush(const Duration(milliseconds: 250));
    } else {
      _cancelBackoffTimer();
      _cancelFlushTimer();
    }
  }

  void setActorUserId(String? userId) {
    _actorUserId = _normalizeUuid(userId);
  }

  /// Records the active UI locale so funnel reporting can compare the English
  /// and Slovenian experiences. Language tag only — never a region-precise or
  /// user-identifying value.
  void setLocale(String? languageTag) {
    _locale = _clampText(languageTag, 16);
  }

  void notifyRoute(PageRoute<dynamic> route) {
    unawaited(_handleRoute(route));
  }

  Future<void> _handleRoute(PageRoute<dynamic> route) async {
    await ensureInitialized();
    if (!_enabled) return;

    final rawRouteName = (route.settings.name ?? '').trim();

    // Match on the PATH, not the raw route name.
    //
    // A campaign landing arrives as `/register?utm_source=meta&...`, and the
    // raw name is what `onGenerateInitialRoutes` passes through verbatim. Exact
    // comparisons like `name == '/register'` therefore failed for precisely the
    // entries we most need to measure, so `signup_view` never fired for a
    // direct ad landing. Stripping the query also keeps `screen_name` /
    // `screen_route` low-cardinality — otherwise every distinct utm_* triple
    // minted a new screen value and blew up the grouping dimensions.
    final routeName = _routePathOf(rawRouteName);
    final screenRoute = routeName.isNotEmpty ? routeName : null;

    final screenName = _screenNameForRouteName(routeName) ??
        screenRoute ??
        route.runtimeType.toString();

    setActiveScreen(screenName: screenName, screenRoute: screenRoute);
  }

  void setActiveScreen({required String screenName, String? screenRoute}) {
    unawaited(
      _setActiveScreenAsync(screenName: screenName, screenRoute: screenRoute),
    );
  }

  Future<void> _setActiveScreenAsync({
    required String screenName,
    String? screenRoute,
  }) async {
    await ensureInitialized();
    if (!_enabled) return;

    _rotateSessionIfNeeded();

    final normalizedName =
        screenName.trim().isEmpty ? 'unknown' : screenName.trim();
    final normalizedRoute = (screenRoute ?? '').trim();
    final routeOrNull = normalizedRoute.isEmpty ? null : normalizedRoute;

    if (_screenName == normalizedName &&
        (_screenRoute ?? '') == (routeOrNull ?? '')) {
      return;
    }

    await _emitScreenDurationIfNeeded();

    _screenName = normalizedName;
    _screenRoute = routeOrNull;
    _screenEnteredAtUtc = DateTime.now().toUtc();

    _updateFlowStageFromScreen();
    _syncClientContext();

    await trackEvent(AppTelemetryEventTypes.screenView);

    if (_isOnboardingScreen(_screenName, _screenRoute)) {
      await _trackOncePerSession(AppTelemetryEventTypes.onboardingEnter);
    }

    if (_isSignInViewScreen(_screenName, _screenRoute)) {
      await trackEvent(AppTelemetryEventTypes.signInView);
    }

    if (_isSignUpViewScreen(_screenName, _screenRoute)) {
      await trackEvent(AppTelemetryEventTypes.signUpView);
    }
  }

  Future<void> trackOnboardingComplete({required String reason}) async {
    await ensureInitialized();
    if (!_enabled) return;
    await _trackOncePerSession(
      AppTelemetryEventTypes.onboardingComplete,
      extra: {'success': true, 'onboarding_reason': _clampText(reason, 64)},
    );
  }

  Future<void> trackSignInAttempt({required String method}) async {
    await trackEvent(
      AppTelemetryEventTypes.signInAttempt,
      extra: {'method': _clampText(method, 32), 'success': false},
    );
  }

  Future<void> trackSignInSuccess({required String method}) async {
    await trackEvent(
      AppTelemetryEventTypes.signInSuccess,
      extra: {'method': _clampText(method, 32), 'success': true},
    );
  }

  Future<void> trackSignInFailure({
    required String method,
    required String errorClass,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.signInFailure,
      extra: {
        'method': _clampText(method, 32),
        'success': false,
        'error_class': _clampText(errorClass, 64),
      },
    );
  }

  Future<void> trackSignUpAttempt({required String method}) async {
    await trackEvent(
      AppTelemetryEventTypes.signUpAttempt,
      extra: {'method': _clampText(method, 32), 'success': false},
    );
  }

  Future<void> trackSignUpSuccess({required String method}) async {
    await trackEvent(
      AppTelemetryEventTypes.signUpSuccess,
      extra: {'method': _clampText(method, 32), 'success': true},
    );
  }

  Future<void> trackSignUpFailure({
    required String method,
    required String errorClass,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.signUpFailure,
      extra: {
        'method': _clampText(method, 32),
        'success': false,
        'error_class': _clampText(errorClass, 64),
      },
    );
  }

  Future<void> trackArSessionStart() async {
    await trackEvent(AppTelemetryEventTypes.arSessionStart);
  }

  /// Guest-first funnel events. Fired once per session so acquisition analytics
  /// can attribute ad clicks to guest app/map usage. Campaign attribution
  /// (utm_*, entry_intent) is attached automatically via `_buildMetadata`.
  Future<void> trackGuestAppLoaded() async {
    await _trackOncePerSession(AppTelemetryEventTypes.guestAppLoaded);
  }

  Future<void> trackGuestMapLoaded() async {
    await _trackOncePerSession(AppTelemetryEventTypes.guestMapLoaded);
  }

  /// Public discovery funnel. These power institutional pilot reporting (how
  /// visitors discover and engage with a programme). Pass only ids / coarse
  /// context — never precise location history.
  Future<void> trackMapOpened() async {
    await _trackOncePerSession(AppTelemetryEventTypes.mapOpened);
  }

  Future<void> trackNearbyDiscoveryUsed() async {
    await trackEvent(AppTelemetryEventTypes.nearbyDiscoveryUsed);
  }

  Future<void> trackArtworkViewed(
    String artworkId, {
    String? institutionId,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.artworkViewed,
      extra: {
        'artwork_id': artworkId,
        if (institutionId != null) 'institution_id': institutionId,
      },
    );
  }

  Future<void> trackEventViewed(String eventId, {String? institutionId}) async {
    await trackEvent(
      AppTelemetryEventTypes.eventViewed,
      extra: {
        'event_id': eventId,
        if (institutionId != null) 'institution_id': institutionId,
      },
    );
  }

  Future<void> trackInstitutionViewed(String institutionId) async {
    await trackEvent(
      AppTelemetryEventTypes.institutionViewed,
      extra: {'institution_id': institutionId},
    );
  }

  Future<void> trackRouteOpened(String routeId) async {
    await trackEvent(
      AppTelemetryEventTypes.routeOpened,
      extra: {'route_id': routeId},
    );
  }

  Future<void> trackRouteStarted(String routeId) async {
    await trackEvent(
      AppTelemetryEventTypes.routeStarted,
      extra: {'route_id': routeId},
    );
  }

  Future<void> trackRouteCompleted(String routeId) async {
    await trackEvent(
      AppTelemetryEventTypes.routeCompleted,
      extra: {'route_id': routeId},
    );
  }

  Future<void> trackQrOpened({
    String? campaign,
    String? targetType,
    String? targetId,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.qrOpened,
      extra: {
        if (campaign != null) 'campaign': campaign,
        if (targetType != null) 'target_type': targetType,
        if (targetId != null) 'target_id': targetId,
      },
    );
  }

  /// A durable contribution attempt has actually begun.
  ///
  /// "Begun" means the submission operation is running — not that a creator
  /// screen opened, a draft was made or a field was typed into. Those are not
  /// attempts and counting them would make the started -> submitted ratio
  /// describe UI curiosity rather than publishing.
  Future<void> trackContributionStarted({
    required ContributionType type,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.contributionStarted,
      extra: _contributionDimensions(type),
    );
  }

  /// A durable contribution now exists, confirmed by the backend.
  ///
  /// Never called on validation failure, a failed API call, media upload alone,
  /// or an update to something that already existed.
  Future<void> trackContributionSubmitted({
    required ContributionType type,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.contributionSubmitted,
      extra: _contributionDimensions(type),
    );
  }

  /// Emits everything a confirmed contribution owes analytics, in one call.
  ///
  /// The four creation paths otherwise each repeated the same sequence —
  /// submitted event, first-contribution milestone, canonical type, swallow
  /// telemetry errors — and three of them would have had to grow it from
  /// scratch. Divergence there is invisible: the funnel simply under-reports
  /// whichever path forgot a step.
  ///
  /// Returns normally on any telemetry failure. Callers invoke this *after*
  /// their product transaction has succeeded, so there is nothing left for an
  /// exception here to protect.
  Future<void> trackSuccessfulContribution(ContributionType type) async {
    try {
      await trackContributionSubmitted(type: type);
      await trackFirstEngagement(
        milestone: PendingActionMilestone.contribution,
        targetType: type.wireValue,
      );
    } catch (_) {
      // Observability is not transaction logic.
    }
  }

  /// `contribution_type` is the canonical key. `kind` is still sent with the
  /// same value so a backend that predates the enum keeps recording these
  /// events exactly as it does today — during a rollout the app can be ahead of
  /// the API, and an activation must not depend on which shipped first.
  Map<String, Object?> _contributionDimensions(ContributionType type) => {
        'contribution_type': type.wireValue,
        'kind': type.wireValue,
      };

  /// Reserved for a genuine one-time public artist-identity creation or claim.
  ///
  /// Intentionally has no call site: artist standing in this product is derived
  /// from profile fields and DAO review, so there is no moment to fire it at.
  /// See `docs/analytics/campaign-activation-contract.md`.
  @visibleForTesting
  Future<void> trackArtistProfileCreated({bool claimed = false}) async {
    await trackEvent(
      AppTelemetryEventTypes.artistProfileCreated,
      extra: {'claimed': claimed},
    );
  }

  Future<void> trackInstitutionalCtaClicked(String cta) async {
    await trackEvent(
      AppTelemetryEventTypes.institutionalCtaClicked,
      extra: {'cta': cta},
    );
  }

  Future<void> trackExhibitionViewed(
    String exhibitionId, {
    String? institutionId,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.exhibitionViewed,
      extra: {
        'exhibition_id': exhibitionId,
        if (institutionId != null) 'institution_id': institutionId,
      },
    );
  }

  // ===========================================================================
  // Guest -> account activation funnel
  //
  // Every stage below reports only what has actually happened. In particular
  // `registrationSubmitted` is not `accountSessionCreated`, and neither implies
  // the visitor completed the action that motivated the account.
  // ===========================================================================

  /// A guest tapped an identity-dependent action.
  Future<void> trackProtectedActionClicked({
    required String actionType,
    required String targetType,
    String? sourceScreen,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.protectedActionClicked,
      extra: {
        'action_type': actionType,
        'target_type': targetType,
        if (sourceScreen != null) 'source_screen': sourceScreen,
      },
    );
  }

  /// The contextual activation surface was shown. Deduped per attempted
  /// action+target so a rebuild cannot inflate the stage.
  Future<void> trackAuthGateViewed({
    required String actionType,
    required String targetType,
    String? sourceScreen,
  }) async {
    await _trackOnceWithKey(
      AppTelemetryEventTypes.authGateViewed,
      dedupeKey: '$actionType:$targetType',
      extra: {
        'action_type': actionType,
        'target_type': targetType,
        if (sourceScreen != null) 'source_screen': sourceScreen,
      },
    );
  }

  Future<void> trackAuthGateDismissed({
    required String actionType,
    required String targetType,
    String? sourceScreen,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.authGateDismissed,
      extra: {
        'action_type': actionType,
        'target_type': targetType,
        if (sourceScreen != null) 'source_screen': sourceScreen,
      },
    );
  }

  Future<void> trackAuthMethodSelected({
    required String method,
    String? actionType,
    String? targetType,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.authMethodSelected,
      extra: {
        'auth_method': _clampText(method, 32),
        if (actionType != null) 'action_type': actionType,
        if (targetType != null) 'target_type': targetType,
      },
    );
  }

  /// A registration request was accepted by the backend. This is explicitly
  /// NOT an activated account: for email the visitor still has to verify.
  Future<void> trackRegistrationSubmitted({
    required String method,
    bool requiresEmailVerification = false,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.registrationSubmitted,
      extra: {
        'auth_method': _clampText(method, 32),
        'method': _clampText(method, 32),
        'requires_email_verification': requiresEmailVerification,
      },
    );
  }

  Future<void> trackEmailVerificationSent() async {
    await trackEvent(
      AppTelemetryEventTypes.emailVerificationSent,
      extra: {'auth_method': 'email'},
    );
  }

  Future<void> trackEmailVerificationViewed() async {
    await _trackOncePerSession(
      AppTelemetryEventTypes.emailVerificationViewed,
      extra: {'auth_method': 'email'},
    );
  }

  Future<void> trackEmailVerified() async {
    await _trackOncePerSession(
      AppTelemetryEventTypes.emailVerified,
      extra: {'auth_method': 'email', 'success': true},
    );
  }

  /// A usable authenticated session now exists. This is the only event that
  /// may be read as "the visitor has an account they can act with".
  Future<void> trackAccountSessionCreated({
    required String method,
    required bool isNewAccount,
  }) async {
    await _trackOnceWithKey(
      AppTelemetryEventTypes.accountSessionCreated,
      dedupeKey: method,
      extra: {
        'auth_method': _clampText(method, 32),
        'method': _clampText(method, 32),
        'is_new_account': isNewAccount,
        'success': true,
      },
    );
  }

  Future<void> trackPendingActionRestored({
    required String actionType,
    required String targetType,
    String? sourceScreen,
  }) async {
    await _trackOnceWithKey(
      AppTelemetryEventTypes.pendingActionRestored,
      dedupeKey: '$actionType:$targetType',
      extra: {
        'action_type': actionType,
        'target_type': targetType,
        'continuation_status': 'restored',
        if (sourceScreen != null) 'source_screen': sourceScreen,
      },
    );
  }

  Future<void> trackPendingActionConfirmationViewed({
    required String actionType,
    required String targetType,
  }) async {
    await _trackOnceWithKey(
      AppTelemetryEventTypes.pendingActionConfirmationViewed,
      dedupeKey: '$actionType:$targetType',
      extra: {
        'action_type': actionType,
        'target_type': targetType,
        'continuation_status': 'awaiting_confirmation',
      },
    );
  }

  Future<void> trackPendingActionCompleted({
    required String actionType,
    required String targetType,
  }) async {
    await _trackOnceWithKey(
      AppTelemetryEventTypes.pendingActionCompleted,
      dedupeKey: '$actionType:$targetType',
      extra: {
        'action_type': actionType,
        'target_type': targetType,
        'continuation_status': 'completed',
        'success': true,
      },
    );
  }

  /// [failureStage] is a coarse machine label such as `target_missing`,
  /// `unauthorized`, `expired` or `network` — never a raw error message.
  Future<void> trackPendingActionFailed({
    required String actionType,
    required String targetType,
    required String failureStage,
  }) async {
    await trackEvent(
      AppTelemetryEventTypes.pendingActionFailed,
      extra: {
        'action_type': actionType,
        'target_type': targetType,
        'continuation_status': 'failed',
        'failure_stage': _clampText(failureStage, 48),
        'success': false,
      },
    );
  }

  /// The v1 install-wide first-engagement key.
  ///
  /// Retained only to be read, never written. It claimed to fire once per
  /// account but was scoped to the installation, so the second account to use a
  /// device was permanently unable to record its first contribution — on a
  /// shared browser that is every account after the first.
  @visibleForTesting
  static String legacyFirstEngagementKey(PendingActionMilestone milestone) =>
      'app_telemetry_first_${milestone.name}_v1';

  /// Account-scoped first-engagement key.
  ///
  /// Keyed by the canonical `user_id` UUID the service already normalises —
  /// never email, display name or wallet address, none of which belong in
  /// analytics storage keys, and the last of which is not even stable per
  /// account.
  ///
  /// An unauthenticated contribution has no account to scope to. That flow does
  /// not currently exist — every creation path requires a session — but if one
  /// appears it falls back to the session id, which is honest about being
  /// session-scoped instead of pretending install state is account state.
  @visibleForTesting
  String firstEngagementKey(PendingActionMilestone milestone) {
    final actor = (_actorUserId ?? '').trim();
    final scope = actor.isNotEmpty ? 'user_$actor' : 'session_$_sessionId';
    return 'app_telemetry_first_${milestone.name}_${scope}_v2';
  }

  /// Emits the "first meaningful engagement" milestone for an account.
  ///
  /// Persisted per account, so a second artwork by the same artist does not
  /// fire it again and a different account on the same device still can.
  Future<void> trackFirstEngagement({
    required PendingActionMilestone milestone,
    required String targetType,
  }) async {
    await ensureInitialized();
    if (!_enabled) return;

    final eventType = switch (milestone) {
      PendingActionMilestone.save => AppTelemetryEventTypes.firstSaveCompleted,
      PendingActionMilestone.follow =>
        AppTelemetryEventTypes.firstFollowCompleted,
      PendingActionMilestone.contribution =>
        AppTelemetryEventTypes.firstContributionCompleted,
    };

    final prefsKey = firstEngagementKey(milestone);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(prefsKey) ?? false) return;

      // The v1 flag suppresses only the account that is plausibly the one that
      // set it — the first account seen on this install after the upgrade. It
      // is claimed at that point so it can never suppress a second account, and
      // so the account that already fired the milestone does not fire it twice.
      final legacyKey = legacyFirstEngagementKey(milestone);
      if (prefs.getBool(legacyKey) ?? false) {
        await prefs.remove(legacyKey);
        await prefs.setBool(prefsKey, true);
        return;
      }

      await prefs.setBool(prefsKey, true);
    } catch (_) {
      // Storage unavailable: fall through and emit at most once per session.
      if (_onceKeys.contains('$_sessionId::$eventType')) return;
      _onceKeys.add('$_sessionId::$eventType');
    }

    await trackEvent(
      eventType,
      extra: {'target_type': targetType, 'success': true},
    );
  }

  Future<void> trackActivationPromptViewed({required String trigger}) async {
    await _trackOncePerSession(
      AppTelemetryEventTypes.activationPromptViewed,
      extra: {'prompt_trigger': _clampText(trigger, 32)},
    );
  }

  Future<void> trackActivationPromptDismissed({required String trigger}) async {
    await trackEvent(
      AppTelemetryEventTypes.activationPromptDismissed,
      extra: {'prompt_trigger': _clampText(trigger, 32)},
    );
  }

  Future<void> trackActivationPromptAccepted({required String trigger}) async {
    await trackEvent(
      AppTelemetryEventTypes.activationPromptAccepted,
      extra: {'prompt_trigger': _clampText(trigger, 32)},
    );
  }

  Map<String, Object?> _loadEntryAttribution(SharedPreferences prefs) {
    try {
      final attribution = <String, Object?>{};
      GuestSessionService.entryUtmSync(prefs).forEach((key, value) {
        attribution[key] = value;
      });
      final intent = GuestSessionService.entryIntentSync(prefs);
      if (intent != null) attribution['entry_intent'] = intent;
      // Landing surface for this visitor — path only, never the query string.
      // Answers "did this campaign land on /register or /map?" without storing
      // arbitrary parameter values.
      final entryRoute = GuestSessionService.entryRouteSync(prefs);
      if (entryRoute != null) attribution['entry_route'] = entryRoute;
      if (GuestSessionService.isGuestActiveSync(prefs)) {
        attribution['guest'] = true;
      }
      return attribution;
    } catch (_) {
      return const <String, Object?>{};
    }
  }

  /// Re-read entry attribution after it may have changed.
  ///
  /// `_entryAttribution` is snapshotted once during [ensureInitialized], so a
  /// capture or `activateGuestMode` that lands afterwards would otherwise be
  /// invisible to every later event in the process.
  Future<void> refreshEntryAttribution({SharedPreferences? prefs}) async {
    if (!_initialized) return;
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      _entryAttribution = _loadEntryAttribution(p);
    } catch (_) {
      // Attribution refresh must never break the app.
    }
  }

  /// First-touch app entry for every visitor, once per session.
  ///
  /// This is the denominator for direct-acquisition campaigns, which never
  /// emit [AppTelemetryEventTypes.guestAppLoaded] because they land straight on
  /// `/register` rather than through the guest map.
  Future<void> trackAppEntry() async {
    await _trackOncePerSession(AppTelemetryEventTypes.appEntry);
  }

  Future<void> trackEvent(
    String eventType, {
    Map<String, Object?> extra = const {},
  }) async {
    await ensureInitialized();
    if (!_enabled) return;
    final normalizedEventType = eventType.trim();
    if (!AppTelemetryEventTypes.allowed.contains(normalizedEventType)) return;

    _rotateSessionIfNeeded();
    await _refreshEntryAttributionForEmission();

    final metadata = _buildMetadata(extra: extra);
    final payload = AppTelemetryEvent(
      eventId: TelemetryUuid.v4(),
      eventTimeUtc: DateTime.now().toUtc(),
      eventType: normalizedEventType,
      sessionId: _sessionId,
      actorUserId: _actorUserId,
      metadata: metadata,
    );

    final encodedBytes = utf8.encode(payload.toJsonString()).length;
    if (encodedBytes > AppTelemetryConfig.maxEventBytes) {
      final clipped = Map<String, Object?>.from(metadata);
      clipped['truncated'] = true;
      clipped.removeWhere((k, _) {
        return k != 'property' &&
            k != 'screen_name' &&
            k != 'screen_route' &&
            k != 'flow_stage' &&
            k != 'app_version' &&
            k != 'build_number' &&
            k != 'platform' &&
            k != 'env' &&
            k != 'truncated';
      });
      final clippedEvent = AppTelemetryEvent(
        eventId: payload.eventId,
        eventTimeUtc: payload.eventTimeUtc,
        eventType: payload.eventType,
        sessionId: payload.sessionId,
        actorUserId: payload.actorUserId,
        metadata: clipped,
      );
      await _queue.enqueue(clippedEvent);
    } else {
      await _queue.enqueue(payload);
    }

    _scheduleFlush(AppTelemetryConfig.flushOnEnqueueDelay);
  }

  void onAppLifecycleChanged(AppLifecycleState state) {
    unawaited(_handleLifecycle(state));
  }

  Future<void> _handleLifecycle(AppLifecycleState state) async {
    await ensureInitialized();
    if (!_enabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      await _emitScreenDurationIfNeeded();
      _screenEnteredAtUtc = null;
      _scheduleFlush(const Duration(milliseconds: 250));
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _screenEnteredAtUtc ??= DateTime.now().toUtc();
      _scheduleFlush(const Duration(milliseconds: 250));
    }
  }

  Future<void> flushNow() async {
    await ensureInitialized();
    if (!_enabled) return;
    await _flush();
  }

  Future<void> _emitScreenDurationIfNeeded() async {
    final enteredAt = _screenEnteredAtUtc;
    if (enteredAt == null) return;
    final now = DateTime.now().toUtc();
    final durationMs = now.difference(enteredAt).inMilliseconds;
    if (durationMs <= 0) return;

    await _refreshEntryAttributionForEmission();

    final metadata = _buildMetadata(
      extra: {'duration_ms': durationMs},
      screenOverride: _screenName,
      screenRouteOverride: _screenRoute,
    );

    final event = AppTelemetryEvent(
      eventId: TelemetryUuid.v4(),
      eventTimeUtc: now,
      eventType: AppTelemetryEventTypes.screenDuration,
      sessionId: _sessionId,
      actorUserId: _actorUserId,
      metadata: metadata,
    );

    await _queue.enqueue(event);
  }

  Future<void> _trackOncePerSession(
    String eventType, {
    Map<String, Object?> extra = const {},
  }) async {
    await ensureInitialized();
    if (!_enabled) return;
    _rotateSessionIfNeeded();

    final key = '$_sessionId::$eventType';
    if (_onceKeys.contains(key)) return;
    _onceKeys.add(key);
    await trackEvent(eventType, extra: extra);
  }

  /// Emits [eventType] at most once per session per [dedupeKey].
  ///
  /// Funnel stages are driven by navigation and rebuilds, so the same stage can
  /// legitimately be reached several times for the same target. Keying the
  /// guard by target keeps counts honest without suppressing a genuinely
  /// different attempt later in the session.
  Future<void> _trackOnceWithKey(
    String eventType, {
    required String dedupeKey,
    Map<String, Object?> extra = const {},
  }) async {
    await ensureInitialized();
    if (!_enabled) return;
    _rotateSessionIfNeeded();

    final key = '$_sessionId::$eventType::$dedupeKey';
    if (_onceKeys.contains(key)) return;
    _onceKeys.add(key);
    await trackEvent(eventType, extra: extra);
  }

  Map<String, Object?> _buildMetadata({
    required Map<String, Object?> extra,
    String? screenOverride,
    String? screenRouteOverride,
  }) {
    final base = <String, Object?>{
      'property': AppTelemetryConfig.property,
      'screen_name': _clampText(screenOverride ?? _screenName, 64) ?? 'unknown',
      'screen_route': _clampText(screenRouteOverride ?? _screenRoute, 160),
      'flow_stage': _clampText(_flowStage, 32) ?? 'main',
      'app_version': AppInfo.version,
      'build_number': AppInfo.buildNumber,
      'platform': _platformName(),
      'env': AppTelemetryConfig.env,
      'locale': _locale ?? _platformLocale(),
    };

    // Campaign attribution (utm_*, entry_intent, guest) from the marketing
    // funnel. Added before `extra` so explicit per-event values still win.
    base.addAll(_entryAttribution);

    for (final entry in extra.entries) {
      final key = entry.key.toString();
      if (key.isEmpty) continue;
      // Structural, not exact-match: `user_email` and `wallet_address` used to
      // pass a name-equality check. The backend sanitiser is the authoritative
      // allowlist; this is defence in depth at the point of capture.
      if (_looksSensitive(key)) continue;
      base[key] = entry.value;
    }

    base.removeWhere((_, v) => v == null);
    return base;
  }

  /// A process can outlive the attribution window (a background mobile app or
  /// an open web tab). Re-read the expiry-aware source immediately before an
  /// emission so the cached initialization snapshot cannot keep attaching a
  /// stale campaign after seven days.
  Future<void> _refreshEntryAttributionForEmission() async {
    if (_entryAttribution.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await GuestSessionService.pruneExpiredAttribution(prefs: prefs);
      _entryAttribution = _loadEntryAttribution(prefs);
    } catch (_) {
      // Telemetry must remain non-blocking if attribution storage is absent.
    }
  }

  /// Nouns that, as a whole key or as a trailing segment, mean the value is
  /// the sensitive thing itself.
  ///
  /// Matched on the whole key or on a `_`-delimited suffix rather than by
  /// substring: `requires_email_verification` is a boolean flag, not an
  /// address, and a plain `contains('email')` would have silently dropped it.
  static const List<String> _sensitiveKeyNouns = <String>[
    'email',
    'wallet',
    'password',
    'secret',
    'token',
    'latitude',
    'longitude',
    'address',
    'phone',
  ];

  /// Substrings that are never acceptable anywhere in a key.
  static const List<String> _forbiddenKeyFragments = <String>[
    'mnemonic',
    'private_key',
    'privatekey',
  ];

  static bool _looksSensitive(String key) {
    final normalized = key.toLowerCase();
    for (final fragment in _forbiddenKeyFragments) {
      if (normalized.contains(fragment)) return true;
    }
    for (final noun in _sensitiveKeyNouns) {
      if (normalized == noun || normalized.endsWith('_$noun')) return true;
    }
    return false;
  }

  /// Language subtag of the device locale, used until the app locale is known.
  /// Deliberately drops the region so the value stays non-identifying.
  String _platformLocale() {
    try {
      final tag = ui.PlatformDispatcher.instance.locale.languageCode.trim();
      return tag.isEmpty ? 'und' : tag;
    } catch (_) {
      return 'und';
    }
  }

  String _platformName() {
    // Avoid early returns + exhaustive switches that can trigger DDC
    // "unreachable code" warnings in debug JS builds.
    String platform = 'web';
    if (!kIsWeb) {
      final target = defaultTargetPlatform;
      if (target == TargetPlatform.android) {
        platform = 'android';
      } else if (target == TargetPlatform.iOS) {
        platform = 'ios';
      } else if (target == TargetPlatform.macOS) {
        platform = 'macos';
      } else if (target == TargetPlatform.windows) {
        platform = 'windows';
      } else if (target == TargetPlatform.linux) {
        platform = 'linux';
      } else if (target == TargetPlatform.fuchsia) {
        platform = 'fuchsia';
      }
    }
    return platform;
  }

  /// Starts a new telemetry session immediately.
  ///
  /// Called on sign-out: the persisted session id would otherwise keep the
  /// departing account's events and the next visitor's events on one chain.
  Future<void> rotateSession() async {
    _sessionId = TelemetryUuid.v4();
    _sessionStartUtc = DateTime.now().toUtc();
    _onceKeys.clear();
    _syncClientContext();
    await _persistSession();
  }

  void _rotateSessionIfNeeded() {
    final now = DateTime.now().toUtc();
    if (now.difference(_sessionStartUtc) < AppTelemetryConfig.sessionRotation) {
      return;
    }
    _sessionId = TelemetryUuid.v4();
    _sessionStartUtc = now;
    _onceKeys.clear();
    _syncClientContext();
    unawaited(_persistSession());
  }

  /// Reuses the previous session when it is still inside the rotation window.
  ///
  /// Activation spans app restarts — a visitor can leave to open a verification
  /// email and come back. Without this, the guest half and the account half of
  /// the funnel land in different `session_id`s and never join.
  void _restoreSession(SharedPreferences prefs) {
    final storedId =
        (prefs.getString(AppTelemetryConfig.sessionIdPrefsKey) ?? '').trim();
    if (!_uuidRegex.hasMatch(storedId)) {
      unawaited(_persistSession());
      return;
    }
    final storedStart = DateTime.tryParse(
      prefs.getString(AppTelemetryConfig.sessionStartPrefsKey) ?? '',
    );
    if (storedStart == null) {
      unawaited(_persistSession());
      return;
    }
    final startedAt = storedStart.toUtc();
    if (DateTime.now().toUtc().difference(startedAt) >=
        AppTelemetryConfig.sessionRotation) {
      unawaited(_persistSession());
      return;
    }
    _sessionId = storedId;
    _sessionStartUtc = startedAt;
    unawaited(_persistSession());
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppTelemetryConfig.sessionIdPrefsKey, _sessionId);
      await prefs.setString(
        AppTelemetryConfig.sessionStartPrefsKey,
        _sessionStartUtc.toIso8601String(),
      );
    } catch (_) {
      // Session correlation is best effort; never block telemetry on storage.
    }
  }

  void _updateFlowStageFromScreen() {
    if (_isOnboardingScreen(_screenName, _screenRoute)) {
      _flowStage = 'onboarding';
    } else if (_isAuthFlowScreen(_screenName, _screenRoute)) {
      _flowStage = 'signin';
    } else {
      _flowStage = 'main';
    }
  }

  void _syncClientContext() {
    KubusClientContext.instance.update(
      sessionId: _sessionId,
      screenName: _screenName,
      screenRoute: _screenRoute,
      flowStage: _flowStage,
    );
  }

  /// Path portion of a route name, without query or fragment.
  ///
  /// Named routes are usually bare (`/register`), but a web deep link arrives
  /// with the launch query attached (`/register?utm_source=meta`). Everything
  /// downstream — screen naming, the signup/sign-in/onboarding predicates and
  /// the reported `screen_route` — wants the path alone.
  static String _routePathOf(String routeName) {
    final name = routeName.trim();
    if (name.isEmpty) return '';
    final path = Uri.tryParse(name)?.path;
    if (path == null || path.isEmpty) {
      return name.split('?').first.split('#').first;
    }
    return path;
  }

  String? _screenNameForRouteName(String routeName) {
    final name = routeName.trim();
    if (name.isEmpty) return null;
    if (name == '/' || name == '/init') return 'AppInitializer';
    if (name == '/main') return 'MainApp';
    if (name == '/sign-in') return 'SignIn';
    if (name == '/register') return 'Register';
    if (name == '/ar') return 'AR';
    if (name.startsWith('/wallet_connect') ||
        name.startsWith('/connect_wallet') ||
        name.startsWith('/connect-wallet')) {
      return 'ConnectWallet';
    }
    if (name.startsWith('/artwork')) return 'ArtworkDetail';
    if (name.startsWith('/onboarding')) return 'Onboarding';
    return null;
  }

  bool _isOnboardingScreen(String screenName, String? screenRoute) {
    final lowerName = screenName.toLowerCase();
    final lowerRoute = (screenRoute ?? '').toLowerCase();
    return lowerName.contains('onboarding') ||
        lowerRoute.startsWith('/onboarding');
  }

  bool _isAuthFlowScreen(String screenName, String? screenRoute) {
    final lowerName = screenName.toLowerCase();
    final lowerRoute = (screenRoute ?? '').toLowerCase();
    return lowerRoute.startsWith('/sign-in') ||
        lowerRoute.startsWith('/register') ||
        lowerRoute.startsWith('/connect-wallet') ||
        lowerRoute.startsWith('/connect_wallet') ||
        lowerRoute.startsWith('/wallet_connect') ||
        lowerName.contains('signin');
  }

  bool _isSignInViewScreen(String screenName, String? screenRoute) {
    final lowerName = screenName.toLowerCase();
    final lowerRoute = (screenRoute ?? '').toLowerCase();
    return lowerRoute == '/sign-in' || lowerName == 'signin';
  }

  bool _isSignUpViewScreen(String screenName, String? screenRoute) {
    final lowerName = screenName.toLowerCase();
    final lowerRoute = (screenRoute ?? '').toLowerCase();
    return lowerRoute == '/register' || lowerName == 'register';
  }

  static String? _normalizeUuid(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return _uuidRegex.hasMatch(v) ? v : null;
  }

  static String? _clampText(String? value, int maxLen) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    return raw.length > maxLen ? raw.substring(0, maxLen) : raw;
  }

  void _scheduleFlush(Duration delay) {
    if (!_enabled) return;
    if (_backoffTimer != null) return;
    final now = DateTime.now().toUtc();
    final desiredAt = now.add(delay);

    final currentFireAt = _flushScheduledForUtc;
    if (currentFireAt != null && !desiredAt.isBefore(currentFireAt)) {
      return;
    }

    _cancelFlushTimer();
    _flushScheduledForUtc = desiredAt;
    _flushTimer = Timer(desiredAt.difference(now), () {
      _flushTimer = null;
      _flushScheduledForUtc = null;
      unawaited(_flush());
    });
  }

  void _cancelFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _flushScheduledForUtc = null;
  }

  void _cancelBackoffTimer() {
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  Future<void> _flush() async {
    if (_flushing) return;
    if (!_enabled) return;
    if (_backoffTimer != null) return;

    _flushing = true;
    try {
      final batch = await _queue.peekBatch(AppTelemetryConfig.maxBatchSize);
      if (batch.isEmpty) return;

      final result = await _sender.sendBatch(batch);
      if (result.ok) {
        _consecutiveFailures = 0;
        _cancelBackoffTimer();
        await _queue.removeFirst(batch.length);
        final remaining = await _queue.count();
        if (remaining > 0) {
          _scheduleFlush(const Duration(milliseconds: 250));
        }
        return;
      }

      if (result.shouldDrop) {
        _consecutiveFailures = 0;
        _cancelBackoffTimer();
        await _queue.removeFirst(batch.length);
        final remaining = await _queue.count();
        if (remaining > 0) {
          _scheduleFlush(const Duration(milliseconds: 500));
        }
        return;
      }

      _consecutiveFailures += 1;
      final retryAfter = result.retryAfter;
      final backoff = retryAfter ?? _computeBackoff(_consecutiveFailures);
      _cancelFlushTimer();
      _cancelBackoffTimer();
      _backoffTimer = Timer(backoff, () {
        _backoffTimer = null;
        unawaited(_flush());
      });
    } finally {
      _flushing = false;
    }
  }

  Duration _computeBackoff(int failures) {
    final exp = failures.clamp(1, 10);
    final baseMs = AppTelemetryConfig.baseBackoff.inMilliseconds;
    final maxMs = AppTelemetryConfig.maxBackoff.inMilliseconds;
    final backoffMs = min(maxMs, baseMs * (1 << (exp - 1)));
    final jitter = _rand.nextInt(500);
    return Duration(milliseconds: backoffMs + jitter);
  }
}
