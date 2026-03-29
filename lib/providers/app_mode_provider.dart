import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/public_action_outbox_service.dart';
import '../services/public_fallback_service.dart';

class AppModeProvider extends ChangeNotifier {
  AppModeProvider({
    PublicFallbackService? fallbackService,
    PublicActionOutboxService? outboxService,
  })  : _fallbackService = fallbackService ?? PublicFallbackService(),
        _outboxService = outboxService ?? PublicActionOutboxService() {
    _fallbackService.addListener(_handleDependencyChanged);
    _outboxService.addListener(_handleDependencyChanged);
  }

  final PublicFallbackService _fallbackService;
  final PublicActionOutboxService _outboxService;
  Future<void>? _initializeFuture;

  AppRuntimeMode get mode => _fallbackService.mode;
  bool get isLiveMode => mode == AppRuntimeMode.live;
  bool get isStandbyMode => mode == AppRuntimeMode.standby;
  bool get isIpfsFallbackMode => mode == AppRuntimeMode.ipfsFallback;
  int get queuedActionCount => _outboxService.queuedActionCount;

  String? get statusLabel {
    switch (mode) {
      case AppRuntimeMode.live:
        return null;
      case AppRuntimeMode.standby:
        return 'Standby backend active';
      case AppRuntimeMode.ipfsFallback:
        return 'Public snapshot fallback active';
    }
  }

  String unavailableMessageFor(String featureLabel) {
    final label = featureLabel.trim().isEmpty ? 'This feature' : featureLabel;
    if (mode == AppRuntimeMode.ipfsFallback) {
      return '$label is unavailable while the app is running on public snapshot fallback.';
    }
    if (mode == AppRuntimeMode.standby) {
      return '$label is temporarily degraded while the standby backend is active.';
    }
    return '$label is unavailable.';
  }

  Future<void> initialize() {
    final existing = _initializeFuture;
    if (existing != null) return existing;

    final completer = Completer<void>();
    _initializeFuture = completer.future;

    () async {
      try {
        await _fallbackService.initialize();
        await _outboxService.initialize();
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
        _initializeFuture = null;
      }
    }();

    return completer.future;
  }

  Future<void> refreshMode() => _fallbackService.refreshBackendMode();

  void _handleDependencyChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _fallbackService.removeListener(_handleDependencyChanged);
    _outboxService.removeListener(_handleDependencyChanged);
    super.dispose();
  }
}
