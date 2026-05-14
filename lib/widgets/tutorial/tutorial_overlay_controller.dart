import 'dart:async';

import 'package:flutter/foundation.dart';

import 'interactive_tutorial_overlay.dart';
import 'tutorial_overlay_driver.dart';

@immutable
class TutorialSession {
  const TutorialSession({
    required this.id,
    required this.ownerRoute,
    required this.steps,
    required this.currentIndex,
    this.onPersistSeen,
  });

  final String id;
  final String ownerRoute;
  final List<TutorialStepDefinition> steps;
  final int currentIndex;
  final Future<void> Function()? onPersistSeen;

  TutorialSession copyWith({
    List<TutorialStepDefinition>? steps,
    int? currentIndex,
  }) {
    return TutorialSession(
      id: id,
      ownerRoute: ownerRoute,
      steps: steps ?? this.steps,
      currentIndex: currentIndex ?? this.currentIndex,
      onPersistSeen: onPersistSeen,
    );
  }
}

class _SessionDriver extends ChangeNotifier implements TutorialOverlayDriver {
  _SessionDriver({required TutorialSession session}) : _session = session;

  TutorialSession _session;
  bool _visible = true;

  TutorialSession get session => _session;

  @override
  bool get visible => _visible;

  @override
  int get currentIndex => _session.currentIndex;

  @override
  List<TutorialStepDefinition> get steps =>
      List<TutorialStepDefinition>.unmodifiable(_session.steps);

  @override
  void next() {
    if (_session.steps.isEmpty) {
      _debugLog('sessionNext ignored: empty steps');
      return;
    }
    final isLast = _session.currentIndex >= _session.steps.length - 1;
    _debugLog(
      'sessionNext id=${_session.id} ownerRoute=${_session.ownerRoute} '
      'index=${_session.currentIndex} steps=${_session.steps.length} '
      'isLast=$isLast step="${_currentStepTitle()}"',
    );
    if (_session.currentIndex >= _session.steps.length - 1) {
      unawaited(dismiss());
      return;
    }
    _session = _session.copyWith(currentIndex: _session.currentIndex + 1);
    notifyListeners();
  }

  @override
  void back() {
    if (_session.steps.isEmpty) {
      _debugLog('sessionBack ignored: empty steps');
      return;
    }
    if (_session.currentIndex <= 0) {
      _debugLog(
        'sessionBack ignored: at first step id=${_session.id} '
        'ownerRoute=${_session.ownerRoute}',
      );
      return;
    }
    _debugLog(
      'sessionBack id=${_session.id} ownerRoute=${_session.ownerRoute} '
      'index=${_session.currentIndex} step="${_currentStepTitle()}"',
    );
    _session = _session.copyWith(currentIndex: _session.currentIndex - 1);
    notifyListeners();
  }

  @override
  Future<void> dismiss() async {
    if (!_visible) {
      _debugLog(
        'sessionDismiss ignored: already hidden id=${_session.id} '
        'ownerRoute=${_session.ownerRoute}',
      );
      return;
    }
    _debugLog(
      'sessionDismiss id=${_session.id} ownerRoute=${_session.ownerRoute} '
      'index=${_session.currentIndex} steps=${_session.steps.length} '
      'step="${_currentStepTitle()}" persistedSeen=${_session.onPersistSeen != null}',
    );
    _visible = false;
    notifyListeners();
    try {
      await _session.onPersistSeen?.call();
    } catch (_) {
      // Best-effort.
    }
  }

  String _currentStepTitle() {
    if (_session.steps.isEmpty) return '<none>';
    final index = _session.currentIndex.clamp(0, _session.steps.length - 1);
    return _session.steps[index].title;
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('TutorialOverlayController: $message');
  }
}

/// Root-level tutorial overlay controller.
///
/// Screens either:
/// - bind an external [TutorialOverlayDriver] (e.g. Map tutorial coordinator), or
/// - call [showTutorial] to create an internal session driver.
class TutorialOverlayController extends ChangeNotifier {
  TutorialOverlayDriver? _driver;
  String? _tutorialId;
  String? _ownerRoute;

  TutorialOverlayDriver? get driver => _driver;
  String? get tutorialId => _tutorialId;
  String? get ownerRoute => _ownerRoute;

  void bindDriver({
    required String tutorialId,
    required String ownerRoute,
    required TutorialOverlayDriver driver,
  }) {
    if (identical(_driver, driver) &&
        _tutorialId == tutorialId &&
        _ownerRoute == ownerRoute) {
      return;
    }

    _debugLog(
      'bindDriver tutorialId=$tutorialId ownerRoute=$ownerRoute '
      'visible=${driver.visible} index=${driver.currentIndex} '
      'steps=${driver.steps.length}',
    );
    _unbindCurrentDriver();

    _driver = driver;
    _tutorialId = tutorialId;
    _ownerRoute = ownerRoute;
    driver.addListener(_handleDriverChanged);
    notifyListeners();
  }

  void unbindDriver(TutorialOverlayDriver driver) {
    if (!identical(_driver, driver)) return;
    _debugLog(
      'unbindDriver tutorialId=$_tutorialId ownerRoute=$_ownerRoute '
      'visible=${driver.visible} index=${driver.currentIndex} '
      'steps=${driver.steps.length}',
    );
    _unbindCurrentDriver();
    notifyListeners();
  }

  void showTutorial({
    required String tutorialId,
    required String ownerRoute,
    required List<TutorialStepDefinition> steps,
    Future<void> Function()? onPersistSeen,
  }) {
    final driver = _SessionDriver(
      session: TutorialSession(
        id: tutorialId,
        ownerRoute: ownerRoute,
        steps: List<TutorialStepDefinition>.from(steps),
        currentIndex: 0,
        onPersistSeen: onPersistSeen,
      ),
    );

    bindDriver(
      tutorialId: tutorialId,
      ownerRoute: ownerRoute,
      driver: driver,
    );
  }

  void next() {
    _debugLog(
      'next tutorialId=$_tutorialId ownerRoute=$_ownerRoute '
      'visible=${_driver?.visible} index=${_driver?.currentIndex} '
      'steps=${_driver?.steps.length}',
    );
    _driver?.next();
  }

  void back() {
    _debugLog(
      'back tutorialId=$_tutorialId ownerRoute=$_ownerRoute '
      'visible=${_driver?.visible} index=${_driver?.currentIndex} '
      'steps=${_driver?.steps.length}',
    );
    _driver?.back();
  }

  Future<void> dismiss() async {
    final driver = _driver;
    if (driver == null) return;
    _debugLog(
      'dismiss tutorialId=$_tutorialId ownerRoute=$_ownerRoute '
      'visible=${driver.visible} index=${driver.currentIndex} '
      'steps=${driver.steps.length}',
    );
    await driver.dismiss();
  }

  void _handleDriverChanged() {
    final driver = _driver;
    _debugLog(
      'driverChanged tutorialId=$_tutorialId ownerRoute=$_ownerRoute '
      'visible=${driver?.visible} index=${driver?.currentIndex} '
      'steps=${driver?.steps.length}',
    );
    notifyListeners();
  }

  void _unbindCurrentDriver() {
    final current = _driver;
    if (current != null) {
      current.removeListener(_handleDriverChanged);
    }
    _driver = null;
    _tutorialId = null;
    _ownerRoute = null;
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('TutorialOverlayController: $message');
  }

  @override
  void dispose() {
    _unbindCurrentDriver();
    super.dispose();
  }
}
