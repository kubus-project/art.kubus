class KubusClientContextSnapshot {
  const KubusClientContextSnapshot({
    required this.sessionId,
    required this.screenName,
    required this.flowStage,
    this.screenRoute,
  });

  final String sessionId;
  final String screenName;
  final String? screenRoute;
  final String flowStage;

  Map<String, String> toHeaders() {
    return {
      'x-kubus-session-id': sessionId,
      'x-kubus-screen-name': screenName,
      if (screenRoute != null && screenRoute!.isNotEmpty) 'x-kubus-screen-route': screenRoute!,
      'x-kubus-flow-stage': flowStage,
    };
  }
}

class KubusClientContext {
  KubusClientContext._();

  static final KubusClientContext instance = KubusClientContext._();

  KubusClientContextSnapshot? _snapshot;
  bool _enabled = false;

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _snapshot = null;
    }
  }

  void update({
    required String sessionId,
    required String screenName,
    String? screenRoute,
    required String flowStage,
  }) {
    if (!_enabled) return;
    final normalizedSession = _clamp(sessionId, 64);
    final normalizedScreen = _clamp(screenName, 64);
    if (normalizedSession == null || normalizedScreen == null) return;
    final normalizedRoute = _clamp(screenRoute, 160);
    final normalizedStage = _clamp(flowStage, 32) ?? 'main';

    _snapshot = KubusClientContextSnapshot(
      sessionId: normalizedSession,
      screenName: normalizedScreen,
      screenRoute: normalizedRoute,
      flowStage: normalizedStage,
    );
  }

  Map<String, String> get headers {
    final snapshot = _snapshot;
    if (!_enabled || snapshot == null) return const {};
    return snapshot.toHeaders();
  }

  static String? _clamp(String? value, int maxLen) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    return raw.length > maxLen ? raw.substring(0, maxLen) : raw;
  }
}

