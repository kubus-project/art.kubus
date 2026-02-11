import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../widgets/tutorial/interactive_tutorial_overlay.dart';

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
class MapTutorialCoordinator extends ChangeNotifier {
  MapTutorialCoordinator({
    required this.seenPreferenceKey,
    Future<SharedPreferences> Function()? sharedPreferencesLoader,
  }) : _sharedPreferencesLoader =
            sharedPreferencesLoader ?? SharedPreferences.getInstance;

  final String seenPreferenceKey;
  final Future<SharedPreferences> Function() _sharedPreferencesLoader;

  MapTutorialState _state = const MapTutorialState();
  List<MapTutorialStepBinding> _bindings = const <MapTutorialStepBinding>[];
  List<TutorialStepDefinition> _resolvedSteps = const <TutorialStepDefinition>[];
  bool _startRequested = false;
  bool _startInFlight = false;

  MapTutorialState get state => _state;
  List<TutorialStepDefinition> get steps =>
      List<TutorialStepDefinition>.unmodifiable(_resolvedSteps);

  List<GlobalKey?> get targets =>
      _resolvedSteps.map((step) => step.targetKey).toList(growable: false);

  bool get show => _state.show;
  int get index => _state.index;

  void configure({required List<MapTutorialStepBinding> bindings}) {
    final currentSignature = _bindings
        .map((binding) => binding.id)
        .join('|');
    final nextSignature = bindings.map((binding) => binding.id).join('|');
    _bindings = bindings;
    _resolvedSteps = _resolveSteps(_bindings);

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
      _setState(
        _state.copyWith(
          stepCount: nextCount,
          index: nextIndex,
          show: nextShow,
        ),
      );
    }

    if (_startRequested && !_state.show && _resolvedSteps.isNotEmpty) {
      unawaited(_tryStartIfRequested());
    }
  }

  Future<void> maybeStart() async {
    _startRequested = true;
    await _tryStartIfRequested();
  }

  Future<void> _tryStartIfRequested() async {
    if (!_startRequested) return;
    if (_resolvedSteps.isEmpty) return;
    if (_startInFlight) return;
    _startInFlight = true;
    try {
      final prefs = await _sharedPreferencesLoader();
      final seen = prefs.getBool(seenPreferenceKey) ?? false;
      if (seen) {
        _startRequested = false;
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
    } catch (_) {
      // Best-effort.
    } finally {
      _startInFlight = false;
    }
  }

  void next() {
    if (_resolvedSteps.isEmpty) return;
    if (_state.index >= _resolvedSteps.length - 1) {
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

  void back() {
    if (_resolvedSteps.isEmpty) return;
    if (_state.index <= 0) return;
    _setState(
      _state.copyWith(
        show: true,
        index: _state.index - 1,
        stepCount: _resolvedSteps.length,
      ),
    );
  }

  Future<void> dismiss() async {
    _setState(_state.copyWith(show: false));
    _startRequested = false;
    await _persistSeen();
  }

  Future<void> markSeen() async {
    _startRequested = false;
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

  Future<void> _persistSeen() async {
    try {
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
}
