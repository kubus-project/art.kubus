import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../services/share/share_deep_link_parser.dart';

class DeepLinkProvider extends ChangeNotifier {
  ShareDeepLinkTarget? _pending;
  bool _notifyScheduled = false;

  ShareDeepLinkTarget? get pending => _pending;

  void setPending(ShareDeepLinkTarget? target) {
    if (_pending?.type == target?.type && _pending?.id == target?.id) return;
    _pending = target;
    _notifySafely();
  }

  ShareDeepLinkTarget? consumePending() {
    final value = _pending;
    if (value == null) return null;
    _pending = null;
    _notifySafely();
    return value;
  }

  void _notifySafely() {
    // Avoid "setState called during build" when a deep link is seeded during
    // route generation / widget mounting on Flutter web.
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
