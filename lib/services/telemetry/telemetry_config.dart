import '../../config/config.dart';

class AppTelemetryConfig {
  AppTelemetryConfig._();

  static const String property = 'app.kubus.site';
  static const String eventCategory = 'app';
  static const String ingestEndpointPath = '/api/analytics/app';

  static const int maxQueueLength = 500;
  static const int maxBatchSize = 25;
  static const int maxEventBytes = 8 * 1024;

  static const Duration flushOnEnqueueDelay = Duration(seconds: 2);
  static const Duration requestTimeout = Duration(seconds: 6);

  static const Duration baseBackoff = Duration(seconds: 2);
  static const Duration maxBackoff = Duration(minutes: 5);

  static const Duration sessionRotation = Duration(hours: 6);

  static const String queuePrefsKey = 'app_telemetry_queue_v2';
  static const String droppedCountPrefsKey = 'app_telemetry_dropped_v1';

  /// The telemetry session survives an app restart within [sessionRotation].
  ///
  /// Activation is not a single-sitting flow: a visitor can close the app,
  /// open a verification email and come back. Without a persisted session the
  /// guest half and the account half of the funnel land in different sessions
  /// and never join.
  static const String sessionIdPrefsKey = 'app_telemetry_session_id_v1';
  static const String sessionStartPrefsKey = 'app_telemetry_session_start_v1';

  static bool get enabledByBuildFlag => AppConfig.isFeatureEnabled('analytics');
  static String get env => AppConfig.isProduction ? 'prod' : 'dev';
}

/// First-time engagement milestones reported once per account, not per session.
enum PendingActionMilestone { save, follow, contribution }

class AppTelemetryEventTypes {
  AppTelemetryEventTypes._();

  static const String screenView = 'screen_view';
  static const String screenDuration = 'screen_duration';

  static const String onboardingEnter = 'onboarding_enter';
  static const String onboardingComplete = 'onboarding_complete';

  static const String signInView = 'signin_view';
  static const String signInAttempt = 'signin_attempt';
  static const String signInSuccess = 'signin_success';
  static const String signInFailure = 'signin_failure';

  static const String signUpView = 'signup_view';
  static const String signUpAttempt = 'signup_attempt';
  static const String signUpSuccess = 'signup_success';
  static const String signUpFailure = 'signup_failure';
  static const String arSessionStart = 'ar_session_start';

  /// First-touch app entry, once per session, for EVERY visitor.
  ///
  /// [guestAppLoaded] only fires for guest-first entries (`?mode=guest` or a
  /// recognised intent), which left campaigns that link straight to `/register`
  /// with no top-of-funnel event at all — their activation rate was divided by
  /// a denominator that structurally excluded them. This event is the funnel
  /// entry for direct acquisition and carries `entry_route` so a campaign's
  /// landing surface is reportable. [guestAppLoaded] stays exactly as-is, as
  /// the guest-scoped subset, so the map-first funnel is unaffected.
  static const String appEntry = 'app_entry';

  // Guest-first funnel: cold visitors arriving from the marketing site via
  // ?mode=guest. These let acquisition analytics tie ad clicks -> guest app
  // usage -> (optional) signup.
  static const String guestAppLoaded = 'guest_app_loaded';
  static const String guestMapLoaded = 'guest_map_loaded';

  // Public discovery funnel. These support institutional pilot reporting
  // (how visitors discover and engage with a programme). Payloads should carry
  // only ids/coarse context, never precise location history.
  static const String mapOpened = 'map_opened';
  static const String nearbyDiscoveryUsed = 'nearby_discovery_used';
  static const String artworkViewed = 'artwork_viewed';
  static const String eventViewed = 'event_viewed';
  static const String institutionViewed = 'institution_viewed';
  static const String routeOpened = 'route_opened';
  static const String routeStarted = 'route_started';
  static const String routeCompleted = 'route_completed';
  static const String qrOpened = 'qr_opened';

  // Contribution funnel.
  static const String contributionStarted = 'contribution_started';
  static const String contributionSubmitted = 'contribution_submitted';
  static const String artistProfileCreated = 'artist_profile_created';

  // Institutional funnel.
  static const String institutionalCtaClicked = 'institutional_cta_clicked';

  // Guest -> account activation funnel.
  //
  // These describe the bridge between anonymous discovery and an activated
  // account. The stage names are deliberately literal about *what already
  // happened*: a registration record is not a session, and a session is not a
  // completed action.
  static const String protectedActionClicked = 'protected_action_clicked';
  static const String authGateViewed = 'auth_gate_viewed';
  static const String authGateDismissed = 'auth_gate_dismissed';
  static const String authMethodSelected = 'auth_method_selected';
  static const String registrationSubmitted = 'registration_submitted';
  static const String emailVerificationSent = 'email_verification_sent';
  static const String emailVerificationViewed = 'email_verification_viewed';
  static const String emailVerified = 'email_verified';
  static const String accountSessionCreated = 'account_session_created';
  static const String pendingActionRestored = 'pending_action_restored';
  static const String pendingActionConfirmationViewed =
      'pending_action_confirmation_viewed';
  static const String pendingActionCompleted = 'pending_action_completed';
  static const String pendingActionFailed = 'pending_action_failed';
  static const String firstSaveCompleted = 'first_save_completed';
  static const String firstFollowCompleted = 'first_follow_completed';
  static const String firstContributionCompleted =
      'first_contribution_completed';

  // Non-blocking engagement prompt shown after demonstrated interest.
  static const String activationPromptViewed = 'activation_prompt_viewed';
  static const String activationPromptDismissed = 'activation_prompt_dismissed';
  static const String activationPromptAccepted = 'activation_prompt_accepted';

  // Completes the public discovery view taxonomy alongside artwork/event.
  static const String exhibitionViewed = 'exhibition_viewed';

  static const Set<String> allowed = {
    screenView,
    screenDuration,
    appEntry,
    onboardingEnter,
    onboardingComplete,
    signInView,
    signInAttempt,
    signInSuccess,
    signInFailure,
    signUpView,
    signUpAttempt,
    signUpSuccess,
    signUpFailure,
    arSessionStart,
    guestAppLoaded,
    guestMapLoaded,
    mapOpened,
    nearbyDiscoveryUsed,
    artworkViewed,
    eventViewed,
    institutionViewed,
    routeOpened,
    routeStarted,
    routeCompleted,
    qrOpened,
    contributionStarted,
    contributionSubmitted,
    artistProfileCreated,
    institutionalCtaClicked,
    protectedActionClicked,
    authGateViewed,
    authGateDismissed,
    authMethodSelected,
    registrationSubmitted,
    emailVerificationSent,
    emailVerificationViewed,
    emailVerified,
    accountSessionCreated,
    pendingActionRestored,
    pendingActionConfirmationViewed,
    pendingActionCompleted,
    pendingActionFailed,
    firstSaveCompleted,
    firstFollowCompleted,
    firstContributionCompleted,
    activationPromptViewed,
    activationPromptDismissed,
    activationPromptAccepted,
    exhibitionViewed,
  };
}
