import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../services/auth/auth_deep_link_parser.dart';

class AuthDeepLinkProvider extends ChangeNotifier {
  AuthDeepLinkTarget? _pending;
  bool _notifyScheduled = false;

  AuthDeepLinkTarget? get pending => _pending;

  void setPending(AuthDeepLinkTarget? target) {
    if (_pending?.signature() == target?.signature()) return;
    _pending = target;
    _notifySafely();
  }

  AuthDeepLinkTarget? consumePending() {
    final value = _pending;
    if (value == null) return null;
    _pending = null;
    _notifySafely();
    return value;
  }

  void _notifySafely() {
    final SchedulerPhase phase;
    try {
      phase = SchedulerBinding.instance.schedulerPhase;
    } catch (_) {
      notifyListeners();
      return;
    }
    final inBuildPhase =
        phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks;
    if (!inBuildPhase) {
      notifyListeners();
      return;
    }

    if (_notifyScheduled) return;
    _notifyScheduled = true;
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        notifyListeners();
      });
    } catch (_) {
      _notifyScheduled = false;
      notifyListeners();
    }
  }
}

