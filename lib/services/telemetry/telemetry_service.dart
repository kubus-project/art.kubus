import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/config.dart';
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
  bool _analyticsPreferenceEnabled = true;
  bool _enabled = false;
  bool? _enabledByBuildFlagOverride;

  String? _actorUserId;
  late String _sessionId;
  DateTime _sessionStartUtc = DateTime.now().toUtc();

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

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

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

  TelemetryService._test({required TelemetryEventQueue queue, required TelemetrySender sender})
      : _queue = queue,
        _sender = sender;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    _sessionId = TelemetryUuid.v4();
    _sessionStartUtc = DateTime.now().toUtc();

    try {
      final prefs = await SharedPreferences.getInstance();
      _analyticsPreferenceEnabled = prefs.getBool('enableAnalytics') ?? true;
      _actorUserId = _normalizeUuid(prefs.getString('user_id'));
    } catch (_) {
      _analyticsPreferenceEnabled = true;
      _actorUserId = null;
    }

    _enabled = (_enabledByBuildFlagOverride ?? AppTelemetryConfig.enabledByBuildFlag) && _analyticsPreferenceEnabled;
    KubusClientContext.instance.setEnabled(_enabled);

    await _queue.init();

    if (_enabled) {
      _syncClientContext();
      _scheduleFlush(AppTelemetryConfig.flushOnEnqueueDelay);
    }
  }

  void setAnalyticsPreferenceEnabled(bool enabled) {
    _analyticsPreferenceEnabled = enabled;
    _enabled = (_enabledByBuildFlagOverride ?? AppTelemetryConfig.enabledByBuildFlag) && _analyticsPreferenceEnabled;
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

  void notifyRoute(PageRoute<dynamic> route) {
    unawaited(_handleRoute(route));
  }

  Future<void> _handleRoute(PageRoute<dynamic> route) async {
    await ensureInitialized();
    if (!_enabled) return;

    final routeName = (route.settings.name ?? '').trim();
    final screenRoute = routeName.isNotEmpty ? routeName : null;

    final screenName =
        _screenNameForRouteName(routeName) ?? screenRoute ?? route.runtimeType.toString();

    setActiveScreen(screenName: screenName, screenRoute: screenRoute);
  }

  void setActiveScreen({
    required String screenName,
    String? screenRoute,
  }) {
    unawaited(_setActiveScreenAsync(screenName: screenName, screenRoute: screenRoute));
  }

  Future<void> _setActiveScreenAsync({required String screenName, String? screenRoute}) async {
    await ensureInitialized();
    if (!_enabled) return;

    _rotateSessionIfNeeded();

    final normalizedName = screenName.trim().isEmpty ? 'unknown' : screenName.trim();
    final normalizedRoute = (screenRoute ?? '').trim();
    final routeOrNull = normalizedRoute.isEmpty ? null : normalizedRoute;

    if (_screenName == normalizedName && (_screenRoute ?? '') == (routeOrNull ?? '')) {
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
      extra: {
        'success': true,
        'onboarding_reason': _clampText(reason, 64),
      },
    );
  }

  Future<void> trackSignInAttempt({required String method}) async {
    await trackEvent(
      AppTelemetryEventTypes.signInAttempt,
      extra: {
        'method': _clampText(method, 32),
        'success': false,
      },
    );
  }

  Future<void> trackSignInSuccess({required String method}) async {
    await trackEvent(
      AppTelemetryEventTypes.signInSuccess,
      extra: {
        'method': _clampText(method, 32),
        'success': true,
      },
    );
  }

  Future<void> trackSignInFailure({required String method, required String errorClass}) async {
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
      extra: {
        'method': _clampText(method, 32),
        'success': false,
      },
    );
  }

  Future<void> trackSignUpSuccess({required String method}) async {
    await trackEvent(
      AppTelemetryEventTypes.signUpSuccess,
      extra: {
        'method': _clampText(method, 32),
        'success': true,
      },
    );
  }

  Future<void> trackSignUpFailure({required String method, required String errorClass}) async {
    await trackEvent(
      AppTelemetryEventTypes.signUpFailure,
      extra: {
        'method': _clampText(method, 32),
        'success': false,
        'error_class': _clampText(errorClass, 64),
      },
    );
  }

  Future<void> trackEvent(String eventType, {Map<String, Object?> extra = const {}}) async {
    await ensureInitialized();
    if (!_enabled) return;
    final normalizedEventType = eventType.trim();
    if (!AppTelemetryEventTypes.allowed.contains(normalizedEventType)) return;

    _rotateSessionIfNeeded();

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

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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

    final metadata = _buildMetadata(
      extra: {
        'duration_ms': durationMs,
      },
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

  Future<void> _trackOncePerSession(String eventType, {Map<String, Object?> extra = const {}}) async {
    final key = '$_sessionId::$eventType';
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
    };

    for (final entry in extra.entries) {
      final key = entry.key.toString();
      if (key.isEmpty) continue;
      if (key == 'email' || key == 'wallet' || key.contains('mnemonic')) continue;
      base[key] = entry.value;
    }

    base.removeWhere((_, v) => v == null);
    return base;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  void _rotateSessionIfNeeded() {
    final now = DateTime.now().toUtc();
    if (now.difference(_sessionStartUtc) < AppTelemetryConfig.sessionRotation) return;
    _sessionId = TelemetryUuid.v4();
    _sessionStartUtc = now;
    _onceKeys.clear();
    _syncClientContext();
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

  String? _screenNameForRouteName(String routeName) {
    final name = routeName.trim();
    if (name.isEmpty) return null;
    if (name == '/' || name == '/init') return 'AppInitializer';
    if (name == '/main') return 'MainApp';
    if (name == '/sign-in') return 'SignIn';
    if (name == '/register') return 'Register';
    if (name == '/ar') return 'AR';
    if (name.startsWith('/wallet_connect') || name.startsWith('/connect_wallet') || name.startsWith('/connect-wallet')) {
      return 'ConnectWallet';
    }
    if (name.startsWith('/artwork')) return 'ArtworkDetail';
    if (name.startsWith('/onboarding')) return 'Onboarding';
    return null;
  }

  bool _isOnboardingScreen(String screenName, String? screenRoute) {
    final lowerName = screenName.toLowerCase();
    final lowerRoute = (screenRoute ?? '').toLowerCase();
    return lowerName.contains('onboarding') || lowerRoute.startsWith('/onboarding');
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
