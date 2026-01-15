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

  static bool get enabledByBuildFlag => AppConfig.isFeatureEnabled('analytics');
  static String get env => AppConfig.isProduction ? 'prod' : 'dev';
}

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

  static const Set<String> allowed = {
    screenView,
    screenDuration,
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
  };
}

