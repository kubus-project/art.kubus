import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../widgets/tutorial/interactive_tutorial_overlay.dart';
import '../../../widgets/tutorial/tutorial_overlay_driver.dart';

@immutable
class MapTutorialStepBinding {
  const MapTutorialStepBinding({
    required this.id,
    required this.step,
    this.enabled = true,
    this.isAnchorAvailable,
  });

  final String id;
  final TutorialStepDefinition step;
  final bool enabled;

  /// Optional runtime guard for platform/layout-specific anchors.
  final bool Function()? isAnchorAvailable;
}

@immutable
class MapTutorialState {
  const MapTutorialState({
    this.show = false,
    this.index = 0,
    this.stepCount = 0,
  });

  final bool show;
  final int index;
  final int stepCount;

  MapTutorialState copyWith({
    bool? show,
    int? index,
    int? stepCount,
  }) {
    return MapTutorialState(
      show: show ?? this.show,
      index: index ?? this.index,
      stepCount: stepCount ?? this.stepCount,
    );
  }
}

/// Coordinates map tutorial steps, progression, and persisted seen state.
class MapTutorialCoordinator extends ChangeNotifier
    implements TutorialOverlayDriver {
  MapTutorialCoordinator({
    required this.seenPreferenceKey,
    Future<SharedPreferences> Function()? sharedPreferencesLoader,
  }) : _sharedPreferencesLoader =
            sharedPreferencesLoader ?? SharedPreferences.getInstance;

  final String seenPreferenceKey;
  final Future<SharedPreferences> Function() _sharedPreferencesLoader;

  MapTutorialState _state = const MapTutorialState();
  List<MapTutorialStepBinding> _bindings = const <MapTutorialStepBinding>[];
  List<TutorialStepDefinition> _resolvedSteps =
      const <TutorialStepDefinition>[];
  bool _startRequested = false;
  bool _startInFlight = false;
  Timer? _startRetryTimer;
  Timer? _visibleReconfigureRetryTimer;
  int _startRetryAttempts = 0;

  static const Duration _startRetryDelay = Duration(milliseconds: 100);
  static const int _maxStartRetryAttempts = 30;

  MapTutorialState get state => _state;

  @override
  List<TutorialStepDefinition> get steps =>
      List<TutorialStepDefinition>.unmodifiable(_resolvedSteps);

  List<GlobalKey?> get targets =>
      _resolvedSteps.map((step) => step.targetKey).toList(growable: false);

  bool get show => _state.show;
  int get index => _state.index;

  @override
  bool get visible => show;

  @override
  int get currentIndex => index;

  void configure({required List<MapTutorialStepBinding> bindings}) {
    final currentSignature = _bindings.map((binding) => binding.id).join('|');
    final nextSignature = bindings.map((binding) => binding.id).join('|');
    _bindings = bindings;
    final resolvedSteps = _resolveSteps(_bindings);

    if (_state.show &&
        resolvedSteps.isEmpty &&
        _resolvedSteps.isNotEmpty &&
        _hasEnabledBindings(_bindings)) {
      _debugLog(
        'configure: keeping visible tutorial through transient empty anchors '
        'steps=${_resolvedSteps.length} index=${_state.index} '
        'step="${_currentStepTitle()}" persistedSeen=false',
      );
      _scheduleVisibleReconfigureRetry();
      return;
    }

    _visibleReconfigureRetryTimer?.cancel();
    _visibleReconfigureRetryTimer = null;
    _resolvedSteps = resolvedSteps;

    final nextCount = _resolvedSteps.length;
    final int nextIndex;
    if (nextCount == 0) {
      nextIndex = 0;
    } else if (_state.index < 0) {
      nextIndex = 0;
    } else if (_state.index >= nextCount) {
      nextIndex = nextCount - 1;
    } else {
      nextIndex = _state.index;
    }
    final nextShow = _state.show && nextCount > 0;

    if (!(currentSignature == nextSignature &&
        _state.stepCount == nextCount &&
        _state.index == nextIndex &&
        _state.show == nextShow)) {
      _debugLog(
        'configure: show ${_state.show}->$nextShow '
        'index ${_state.index}->$nextIndex '
        'steps ${_state.stepCount}->$nextCount '
        'signature="$currentSignature"->"$nextSignature" '
        'persistedSeen=false',
      );
      _setState(
        _state.copyWith(
          stepCount: nextCount,
          index: nextIndex,
          show: nextShow,
        ),
      );
    }

    if (_startRequested && !_state.show) {
      if (_resolvedSteps.isNotEmpty) {
        _cancelStartRetry();
        unawaited(_tryStartIfRequested());
      } else {
        _scheduleStartRetry();
      }
    }
  }

  Future<void> maybeStart() async {
    _debugLog(
      'maybeStart: requested show=${_state.show} '
      'steps=${_resolvedSteps.length} index=${_state.index}',
    );
    _startRequested = true;
    _startRetryAttempts = 0;
    await _tryStartIfRequested();
  }

  Future<void> _tryStartIfRequested() async {
    if (!_startRequested) return;
    if (_resolvedSteps.isEmpty) {
      _scheduleStartRetry();
      return;
    }
    if (_startInFlight) return;
    _cancelStartRetry();
    _startInFlight = true;
    try {
      final prefs = await _sharedPreferencesLoader();
      final seen = prefs.getBool(seenPreferenceKey) ?? false;
      if (seen) {
        _debugLog('maybeStart: already seen');
        _startRequested = false;
        _cancelStartRetry();
        return;
      }
      _setState(
        _state.copyWith(
          show: true,
          index: 0,
          stepCount: _resolvedSteps.length,
        ),
      );
      _startRequested = false;
      _cancelStartRetry();
      _debugLog(
        'maybeStart: visible steps=${_resolvedSteps.length} '
        'index=${_state.index} step="${_currentStepTitle()}"',
      );
    } catch (_) {
      // Best-effort.
    } finally {
      _startInFlight = false;
    }
  }

  @override
  void next() {
    if (_resolvedSteps.isEmpty) {
      _debugLog('next: ignored empty steps persistedSeen=false');
      return;
    }
    final isLast = _state.index >= _resolvedSteps.length - 1;
    _debugLog(
      'next: index=${_state.index} steps=${_resolvedSteps.length} '
      'isLast=$isLast step="${_currentStepTitle()}"',
    );
    if (isLast) {
      unawaited(dismiss());
      return;
    }
    _setState(
      _state.copyWith(
        show: true,
        index: _state.index + 1,
        stepCount: _resolvedSteps.length,
      ),
    );
  }

  @override
  void back() {
    if (_resolvedSteps.isEmpty) {
      _debugLog('back: ignored empty steps');
      return;
    }
    if (_state.index <= 0) {
      _debugLog('back: ignored first step index=${_state.index}');
      return;
    }
    _debugLog(
      'back: index=${_state.index} steps=${_resolvedSteps.length} '
      'step="${_currentStepTitle()}"',
    );
    _setState(
      _state.copyWith(
        show: true,
        index: _state.index - 1,
        stepCount: _resolvedSteps.length,
      ),
    );
  }

  @override
  Future<void> dismiss() async {
    _debugLog(
      'dismiss: steps=${_resolvedSteps.length} index=${_state.index} '
      'step="${_currentStepTitle()}" persistedSeen=true',
    );
    _setState(_state.copyWith(show: false));
    _startRequested = false;
    _cancelStartRetry();
    _visibleReconfigureRetryTimer?.cancel();
    _visibleReconfigureRetryTimer = null;
    await _persistSeen();
  }

  Future<void> markSeen() async {
    _debugLog(
      'markSeen: steps=${_resolvedSteps.length} index=${_state.index} '
      'step="${_currentStepTitle()}" persistedSeen=true',
    );
    _startRequested = false;
    _cancelStartRetry();
    await _persistSeen();
  }

  List<TutorialStepDefinition> _resolveSteps(
    List<MapTutorialStepBinding> bindings,
  ) {
    final steps = <TutorialStepDefinition>[];
    for (final binding in bindings) {
      if (!binding.enabled) continue;
      final available = binding.isAnchorAvailable?.call() ?? true;
      if (!available) continue;
      steps.add(binding.step);
    }
    return steps;
  }

  bool _hasEnabledBindings(List<MapTutorialStepBinding> bindings) {
    for (final binding in bindings) {
      if (binding.enabled) return true;
    }
    return false;
  }

  void _scheduleStartRetry() {
    if (!_startRequested || _state.show) return;
    if (_startRetryAttempts >= _maxStartRetryAttempts) {
      _debugLog(
        'startRetry: giving up attempts=$_startRetryAttempts '
        'persistedSeen=false',
      );
      return;
    }
    if (_startRetryTimer != null) return;
    _debugLog(
      'startRetry: scheduled attempt=${_startRetryAttempts + 1} '
      'persistedSeen=false',
    );
    _startRetryTimer = Timer(_startRetryDelay, () {
      _startRetryTimer = null;
      if (!_startRequested || _state.show) return;
      _startRetryAttempts += 1;
      _debugLog(
        'startRetry: running attempt=$_startRetryAttempts '
        'persistedSeen=false',
      );
      configure(bindings: _bindings);
      unawaited(_tryStartIfRequested());
    });
  }

  void _cancelStartRetry() {
    _startRetryTimer?.cancel();
    _startRetryTimer = null;
  }

  void _scheduleVisibleReconfigureRetry() {
    if (!_state.show) return;
    if (_visibleReconfigureRetryTimer != null) return;
    _debugLog(
      'visibleReconfigureRetry: scheduled index=${_state.index} '
      'steps=${_resolvedSteps.length} persistedSeen=false',
    );
    _visibleReconfigureRetryTimer = Timer(_startRetryDelay, () {
      _visibleReconfigureRetryTimer = null;
      if (!_state.show) return;
      _debugLog(
        'visibleReconfigureRetry: running index=${_state.index} '
        'steps=${_resolvedSteps.length} persistedSeen=false',
      );
      configure(bindings: _bindings);
    });
  }

  Future<void> _persistSeen() async {
    try {
      _debugLog('persistSeen: key=$seenPreferenceKey value=true');
      final prefs = await _sharedPreferencesLoader();
      await prefs.setBool(seenPreferenceKey, true);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  void _setState(MapTutorialState next) {
    if (next.show == _state.show &&
        next.index == _state.index &&
        next.stepCount == _state.stepCount) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('MapTutorialCoordinator: $message');
  }

  String _currentStepTitle() {
    if (_resolvedSteps.isEmpty) return '<none>';
    final index = _state.index.clamp(0, _resolvedSteps.length - 1);
    return _resolvedSteps[index].title;
  }

  @override
  void dispose() {
    _cancelStartRetry();
    _visibleReconfigureRetryTimer?.cancel();
    _visibleReconfigureRetryTimer = null;
    super.dispose();
  }
}
