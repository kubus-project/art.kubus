import 'package:flutter/foundation.dart';

/// App wide refresh provider to notify components to refresh their data.
class AppRefreshProvider extends ChangeNotifier {
  static const String viewCommunity = 'community';
  static const String viewChat = 'chat';
  static const String viewNotifications = 'notifications';
  static const String viewProfile = 'profile';
  static const String viewPortfolio = 'portfolio';

  static const Duration _viewGrace = Duration(minutes: 3);
  static const Duration _triggerCooldown = Duration(seconds: 3);

  int _globalVersion = 0;
  int _notificationsVersion = 0;
  int _profileVersion = 0;
  int _chatVersion = 0;
  int _communityVersion = 0;
  int _portfolioVersion = 0;

  bool _isAppForeground = true;
  final Map<String, bool> _viewActive = <String, bool>{};
  final Map<String, DateTime> _viewLastActiveAt = <String, DateTime>{};
  final Map<String, DateTime> _lastTriggerAt = <String, DateTime>{};
  final Map<String, int> _debugCounters = <String, int>{};

  int get globalVersion => _globalVersion;
  int get notificationsVersion => _notificationsVersion;
  int get profileVersion => _profileVersion;
  int get chatVersion => _chatVersion;
  int get communityVersion => _communityVersion;
  int get portfolioVersion => _portfolioVersion;
  bool get isAppForeground => _isAppForeground;
  Map<String, int> get debugCounters => Map.unmodifiable(_debugCounters);

  void setAppForeground(bool isForeground) {
    if (_isAppForeground == isForeground) return;
    _isAppForeground = isForeground;
    _bumpDebug('app_foreground_${isForeground ? 'on' : 'off'}');
  }

  void setViewActive(String viewKey, bool isActive) {
    if (viewKey.trim().isEmpty) return;
    final now = DateTime.now();
    if (isActive) {
      _viewLastActiveAt[viewKey] = now;
    }
    _viewActive[viewKey] = isActive;
    _bumpDebug('view_${viewKey}_${isActive ? 'active' : 'inactive'}');
  }

  bool isViewActive(
    String viewKey, {
    Duration grace = _viewGrace,
    bool defaultIfUnknown = true,
  }) {
    if (viewKey.trim().isEmpty) return defaultIfUnknown;
    final active = _viewActive[viewKey];
    if (active == true) return true;
    if (active == false) {
      final last = _viewLastActiveAt[viewKey];
      if (last != null && DateTime.now().difference(last) <= grace) {
        return true;
      }
      return false;
    }
    return defaultIfUnknown;
  }

  bool _shouldTrigger(String key, {bool onlyIfActive = false, String? viewKey}) {
    if (onlyIfActive && viewKey != null) {
      final allowed = isViewActive(viewKey);
      if (!allowed) {
        _bumpDebug('skip_${key}_inactive');
        return false;
      }
    }

    final now = DateTime.now();
    final last = _lastTriggerAt[key];
    if (last != null && now.difference(last) < _triggerCooldown) {
      _bumpDebug('skip_${key}_cooldown');
      return false;
    }
    _lastTriggerAt[key] = now;
    return true;
  }

  void triggerForegroundRefresh() {
    triggerNotifications(onlyIfActive: true);
    triggerChat(onlyIfActive: true);
    triggerCommunity(onlyIfActive: true);
    triggerProfile(onlyIfActive: true);
  }

  void triggerAll() {
    if (!_shouldTrigger('global')) return;
    _globalVersion++;
    _bumpDebug('trigger_global');
    notifyListeners();
  }

  void triggerNotifications({bool onlyIfActive = false}) {
    if (!_shouldTrigger(
      'notifications',
      onlyIfActive: onlyIfActive,
      viewKey: viewNotifications,
    )) {
      return;
    }
    _notificationsVersion++;
    _bumpDebug('trigger_notifications');
    notifyListeners();
  }

  void triggerProfile({bool onlyIfActive = false}) {
    if (!_shouldTrigger(
      'profile',
      onlyIfActive: onlyIfActive,
      viewKey: viewProfile,
    )) {
      return;
    }
    _profileVersion++;
    _bumpDebug('trigger_profile');
    notifyListeners();
  }

  void triggerChat({bool onlyIfActive = false}) {
    if (!_shouldTrigger(
      'chat',
      onlyIfActive: onlyIfActive,
      viewKey: viewChat,
    )) {
      return;
    }
    _chatVersion++;
    _bumpDebug('trigger_chat');
    notifyListeners();
  }

  void triggerCommunity({bool onlyIfActive = false}) {
    if (!_shouldTrigger(
      'community',
      onlyIfActive: onlyIfActive,
      viewKey: viewCommunity,
    )) {
      return;
    }
    _communityVersion++;
    _bumpDebug('trigger_community');
    notifyListeners();
  }

  void triggerPortfolio({bool onlyIfActive = false}) {
    if (!_shouldTrigger(
      'portfolio',
      onlyIfActive: onlyIfActive,
      viewKey: viewPortfolio,
    )) {
      return;
    }
    _portfolioVersion++;
    _bumpDebug('trigger_portfolio');
    notifyListeners();
  }

  void _bumpDebug(String key) {
    if (!kDebugMode) return;
    _debugCounters[key] = (_debugCounters[key] ?? 0) + 1;
  }
}
