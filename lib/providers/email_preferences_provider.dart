import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/email_preferences.dart';
import '../services/backend_api_service.dart';

class EmailPreferencesProvider extends ChangeNotifier {
  EmailPreferencesProvider({BackendApiService? backendApi})
      : _backendApi = backendApi ?? BackendApiService();

  final BackendApiService _backendApi;

  EmailPreferences _preferences = EmailPreferences.defaults();
  bool _initialized = false;
  bool _isLoading = false;
  bool _isUpdating = false;
  Object? _lastError;

  Completer<void>? _initializeCompleter;
  bool _sessionActive = false;

  EmailPreferences get preferences => _preferences;
  bool get initialized => _initialized;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get lastErrorMessage => _lastError?.toString();

  bool get featureEnabled => AppConfig.isFeatureEnabled('emailAuth');

  bool get hasAuthToken {
    return (_backendApi.getAuthToken() ?? '').trim().isNotEmpty;
  }

  bool get canManage => featureEnabled && hasAuthToken;

  void bindSession({required bool hasSession}) {
    if (_sessionActive == hasSession) return;
    _sessionActive = hasSession;
    if (!hasSession) {
      _preferences = EmailPreferences.defaults();
      _initialized = false;
      _isLoading = false;
      _isUpdating = false;
      _lastError = null;
      _initializeCompleter = null;
      notifyListeners();
    }
  }

  Future<void> initialize({bool forceRefresh = false}) {
    if (!featureEnabled) {
      _initialized = true;
      return Future.value();
    }
    if (!hasAuthToken) {
      _initialized = false;
      return Future.value();
    }

    if (_initialized && !forceRefresh) return Future.value();

    final existing = _initializeCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _initializeCompleter = completer;
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    () async {
      try {
        final payload = await _backendApi.getMyEmailPreferences();
        _preferences = _parsePreferences(payload);
        _initialized = true;
      } catch (e) {
        _lastError = e;
      } finally {
        _isLoading = false;
        _initializeCompleter = null;
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      }
    }();

    return completer.future;
  }

  Future<bool> updatePreferences(EmailPreferences next) async {
    if (!canManage) return false;

    final previous = _preferences;
    _preferences = next.copyWith(transactional: true);
    _isUpdating = true;
    _lastError = null;
    notifyListeners();

    try {
      final payload = await _backendApi.updateMyEmailPreferences(next.toJson());
      _preferences = _parsePreferences(payload);
      _initialized = true;
      return true;
    } catch (e) {
      _lastError = e;
      _preferences = previous;
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  EmailPreferences _parsePreferences(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final raw = data['emailPreferences'];
      if (raw is Map<String, dynamic>) return EmailPreferences.fromJson(raw);
      if (raw is Map) return EmailPreferences.fromJson(raw.cast<String, dynamic>());
    }

    final raw = payload['emailPreferences'];
    if (raw is Map<String, dynamic>) return EmailPreferences.fromJson(raw);
    if (raw is Map) return EmailPreferences.fromJson(raw.cast<String, dynamic>());
    return EmailPreferences.defaults();
  }
}

