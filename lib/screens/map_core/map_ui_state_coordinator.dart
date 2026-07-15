import 'package:flutter/foundation.dart';

import '../../models/art_marker.dart';

const Object _unset = Object();

/// The single dominant contextual surface presented over the map.
///
/// Marker selection is stored separately so temporarily opening filters,
/// nearby content, or discovery does not discard the user's map context.
enum MapContextSurface {
  none,
  searchResults,
  filters,
  nearby,
  markerPreview,
  markerDetails,
  createMarker,
  discovery;

  bool get requiresMarkerSelection =>
      this == markerPreview || this == markerDetails;

  bool get canSuspendCurrent =>
      this == searchResults ||
      this == filters ||
      this == nearby ||
      this == markerDetails ||
      this == discovery;

  bool get canBeSuspended => this != none && this != createMarker;
}

/// Discovery progress is persistent only while the map itself is dominant or
/// while the user deliberately expands discovery. It yields to every other
/// contextual surface instead of competing for attention.
bool mapContextAllowsDiscoveryChrome(MapContextSurface surface) =>
    surface == MapContextSurface.none || surface == MapContextSurface.discovery;

/// Defines whether a surface permanently replaces the current context or
/// temporarily suspends it for one explicit restore operation.
enum MapSurfaceTransitionIntent {
  replace,
  suspendCurrent,
}

/// Canonical UI state machine for map screens (mobile + desktop).
///
/// This coordinator owns *UI state only* (selection and contextual surfaces).
/// It intentionally contains:
/// - no BuildContext
/// - no provider reads
/// - no MapLibre controller calls
///
/// Screens remain responsible for executing side effects (navigation, fetches,
/// map controller actions) in response to state changes.
class MapUiStateCoordinator {
  MapUiStateCoordinator();

  final ValueNotifier<MapUiStateSnapshot> _state =
      ValueNotifier<MapUiStateSnapshot>(const MapUiStateSnapshot());

  ValueListenable<MapUiStateSnapshot> get state => _state;

  MapUiStateSnapshot get value => _state.value;

  bool isSurfaceRevisionCurrent(int revision) =>
      value.surfaceRevision == revision;

  void dispose() {
    _state.dispose();
  }

  // --- Marker selection ---

  void setMarkerSelection({
    required int selectionToken,
    required String? selectedMarkerId,
    required ArtMarker? selectedMarker,
    required List<ArtMarker> stackedMarkers,
    required int stackIndex,
    required DateTime? selectedAt,
  }) {
    if (value.contextSurface == MapContextSurface.createMarker &&
        (selectedMarkerId != null || selectedMarker != null)) {
      return;
    }
    final previousSelection = value.markerSelection;
    final isClear = selectedMarkerId == null && selectedMarker == null;
    final hasMatchedMarker = selectedMarkerId != null &&
        selectedMarkerId.trim().isNotEmpty &&
        selectedMarker != null &&
        selectedMarker.id == selectedMarkerId;
    if (!isClear && !hasMatchedMarker) return;

    final MapMarkerSelectionState nextSelection;
    if (isClear) {
      nextSelection = previousSelection.copyWith(
        selectionToken: selectionToken,
        selectedMarkerId: null,
        selectedMarker: null,
        stackedMarkers: const <ArtMarker>[],
        stackIndex: 0,
        selectedAt: null,
      );
    } else {
      final normalizedStack = stackedMarkers.isEmpty
          ? <ArtMarker>[selectedMarker!]
          : List<ArtMarker>.unmodifiable(stackedMarkers);
      nextSelection = previousSelection.copyWith(
        selectionToken: selectionToken,
        selectedMarkerId: selectedMarkerId,
        selectedMarker: selectedMarker,
        stackedMarkers: normalizedStack,
        stackIndex: stackIndex.clamp(0, normalizedStack.length - 1),
        selectedAt: selectedAt,
      );
    }
    final isNewSelection = nextSelection.hasRenderableSelection &&
        (!previousSelection.hasSelection ||
            nextSelection.selectionToken != previousSelection.selectionToken ||
            nextSelection.selectedMarkerId !=
                previousSelection.selectedMarkerId);
    final MapContextSurface nextSurface;
    if (!nextSelection.hasRenderableSelection &&
        value.contextSurface.requiresMarkerSelection) {
      nextSurface = MapContextSurface.none;
    } else if (isNewSelection &&
        value.contextSurface != MapContextSurface.createMarker &&
        !value.tutorial.show) {
      nextSurface = MapContextSurface.markerPreview;
    } else {
      nextSurface = value.contextSurface;
    }
    final suspendedSurface = _validatedSuspendedSurface(
      value.suspendedSurface,
      nextSelection,
    );
    final next = value.copyWith(
      markerSelection: nextSelection,
      contextSurface: nextSurface,
      suspendedSurface:
          nextSurface == MapContextSurface.markerPreview && isNewSelection
              ? null
              : suspendedSurface,
    );
    _publish(next);
  }

  void dismissMarkerSelection({int? nextSelectionToken}) {
    final currentSelection = value.markerSelection;
    final nextSurface = value.contextSurface.requiresMarkerSelection
        ? MapContextSurface.none
        : value.contextSurface;
    final suspendedSurface =
        value.suspendedSurface?.requiresMarkerSelection == true
            ? null
            : value.suspendedSurface;
    final next = value.copyWith(
      markerSelection: currentSelection.copyWith(
        selectionToken: nextSelectionToken ?? currentSelection.selectionToken,
        selectedMarkerId: null,
        selectedMarker: null,
        stackedMarkers: const <ArtMarker>[],
        stackIndex: 0,
        selectedAt: null,
      ),
      contextSurface: nextSurface,
      suspendedSurface: suspendedSurface,
    );
    _publish(next);
  }

  // --- Dominant contextual surface ---

  /// Replaces the current dominant surface with [surface].
  ///
  /// Marker surfaces require an active marker selection. Invalid requests are
  /// ignored so the snapshot cannot represent a marker card with no marker.
  bool openSurface(
    MapContextSurface surface, {
    MapSurfaceTransitionIntent intent = MapSurfaceTransitionIntent.replace,
  }) {
    if (surface == MapContextSurface.none) {
      closeActiveSurface();
      return true;
    }
    if (surface == MapContextSurface.createMarker) {
      return beginCreateMarker();
    }
    if (surface.requiresMarkerSelection &&
        !value.markerSelection.hasRenderableSelection) {
      return false;
    }
    if (value.contextSurface == MapContextSurface.createMarker &&
        surface != MapContextSurface.createMarker) {
      return false;
    }
    if (value.contextSurface == surface) return false;

    switch (intent) {
      case MapSurfaceTransitionIntent.replace:
        _setSurface(surface, suspendedSurface: null);
      case MapSurfaceTransitionIntent.suspendCurrent:
        if (!surface.canSuspendCurrent) return false;
        final current = value.contextSurface;
        final currentCanBeSuspended = current.canBeSuspended &&
            _canPresent(current, value.markerSelection);
        final retainedSuspended = _validatedSuspendedSurface(
          value.suspendedSurface,
          value.markerSelection,
        );
        _setSurface(
          surface,
          suspendedSurface:
              retainedSuspended ?? (currentCanBeSuspended ? current : null),
        );
    }
    return true;
  }

  /// Starts marker creation as an isolated context.
  ///
  /// Normal marker selection and any resumable surface are cleared so the
  /// pending-position pin is the only map selection presented during creation.
  bool beginCreateMarker() {
    if (value.contextSurface == MapContextSurface.createMarker) return false;
    final selection = value.markerSelection;
    _publish(
      value.copyWith(
        markerSelection: selection.copyWith(
          selectedMarkerId: null,
          selectedMarker: null,
          stackedMarkers: const <ArtMarker>[],
          stackIndex: 0,
          selectedAt: null,
        ),
        contextSurface: MapContextSurface.createMarker,
        suspendedSurface: null,
        selectedSubjectType: null,
        selectedClusterId: null,
      ),
    );
    return true;
  }

  /// Closes [surface] only when it is currently dominant.
  void closeSurface(MapContextSurface surface) {
    if (surface == MapContextSurface.none || value.contextSurface != surface) {
      return;
    }
    _setSurface(MapContextSurface.none, suspendedSurface: null);
  }

  void closeActiveSurface() {
    _setSurface(MapContextSurface.none, suspendedSurface: null);
  }

  /// Opens [surface], or closes it when it is already dominant.
  void toggleSurface(
    MapContextSurface surface, {
    MapSurfaceTransitionIntent intent = MapSurfaceTransitionIntent.replace,
  }) {
    if (surface == MapContextSurface.none) {
      closeActiveSurface();
      return;
    }
    if (value.contextSurface == surface) {
      closeActiveSurface();
      return;
    }
    openSurface(surface, intent: intent);
  }

  /// Restores the one suspended surface and consumes the restore point.
  bool restoreSuspendedSurface() {
    final suspended = _validatedSuspendedSurface(
      value.suspendedSurface,
      value.markerSelection,
    );
    if (suspended == null) {
      if (value.suspendedSurface != null) {
        _publish(value.copyWith(suspendedSurface: null));
      }
      return false;
    }
    _setSurface(suspended, suspendedSurface: null);
    return true;
  }

  bool openMarkerDetails() {
    return openSurface(
      MapContextSurface.markerDetails,
      intent: MapSurfaceTransitionIntent.suspendCurrent,
    );
  }

  /// Implements Back from details without discarding the marker selection.
  void backFromMarkerDetails() {
    if (value.contextSurface != MapContextSurface.markerDetails) return;
    if (!value.markerSelection.hasRenderableSelection) {
      dismissToMap();
      return;
    }
    _setSurface(MapContextSurface.markerPreview, suspendedSurface: null);
  }

  /// Implements Close from details by clearing all map context and selection.
  void closeMarkerDetails({int? nextSelectionToken}) {
    if (value.contextSurface != MapContextSurface.markerDetails) return;
    dismissToMap(nextSelectionToken: nextSelectionToken);
  }

  /// Clears active and suspended surfaces plus marker selection.
  ///
  /// Use for a deliberate background-map dismissal where the expected result
  /// is a clean, context-free map.
  void dismissToMap({int? nextSelectionToken}) {
    final selection = value.markerSelection;
    _publish(
      value.copyWith(
        markerSelection: selection.copyWith(
          selectionToken: nextSelectionToken ?? selection.selectionToken,
          selectedMarkerId: null,
          selectedMarker: null,
          stackedMarkers: const <ArtMarker>[],
          stackIndex: 0,
          selectedAt: null,
        ),
        contextSurface: MapContextSurface.none,
        suspendedSurface: null,
        selectedSubjectType: null,
        selectedClusterId: null,
      ),
    );
  }

  void _setSurface(
    MapContextSurface surface, {
    required MapContextSurface? suspendedSurface,
  }) {
    _publish(
      value.copyWith(
        contextSurface: surface,
        suspendedSurface: suspendedSurface,
      ),
    );
  }

  MapContextSurface? _validatedSuspendedSurface(
    MapContextSurface? surface,
    MapMarkerSelectionState selection,
  ) {
    if (surface == null || !surface.canBeSuspended) return null;
    return _canPresent(surface, selection) ? surface : null;
  }

  bool _canPresent(
    MapContextSurface surface,
    MapMarkerSelectionState selection,
  ) {
    return !surface.requiresMarkerSelection || selection.hasRenderableSelection;
  }

  void _publish(MapUiStateSnapshot next) {
    final current = value;
    if (next == current) return;
    final surfaceChanged = next.contextSurface != current.contextSurface;
    final normalized = surfaceChanged
        ? next.copyWith(surfaceRevision: current.surfaceRevision + 1)
        : next;
    if (normalized == current) return;
    _state.value = normalized;
  }

  // --- Tutorial ---

  void setTutorial({required bool show, required int index}) {
    final nextTutorial = value.tutorial.copyWith(show: show, index: index);
    if (nextTutorial == value.tutorial) return;
    _publish(value.copyWith(tutorial: nextTutorial));
  }
}

@immutable
class MapUiStateSnapshot {
  const MapUiStateSnapshot({
    this.markerSelection = const MapMarkerSelectionState(),
    this.contextSurface = MapContextSurface.none,
    this.suspendedSurface,
    this.surfaceRevision = 0,
    this.selectedSubjectType,
    this.selectedClusterId,
    this.tutorial = const MapTutorialState(),
  });

  final MapMarkerSelectionState markerSelection;

  /// The sole dominant contextual surface visible over the map.
  final MapContextSurface contextSurface;

  /// A single explicitly resumable surface; this is never an unrestricted
  /// navigation stack.
  final MapContextSurface? suspendedSurface;

  /// Monotonically increases whenever [contextSurface] changes.
  final int surfaceRevision;

  /// Optional cross-platform identifier for what kind of subject is selected.
  ///
  /// Example values: 'artwork', 'institution', 'event', 'exhibition'.
  final String? selectedSubjectType;

  /// Optional identifier for selected cluster (if cluster selection is modeled).
  final String? selectedClusterId;

  final MapTutorialState tutorial;

  MapUiStateSnapshot copyWith({
    MapMarkerSelectionState? markerSelection,
    MapContextSurface? contextSurface,
    Object? suspendedSurface = _unset,
    int? surfaceRevision,
    Object? selectedSubjectType = _unset,
    Object? selectedClusterId = _unset,
    MapTutorialState? tutorial,
  }) {
    return MapUiStateSnapshot(
      markerSelection: markerSelection ?? this.markerSelection,
      contextSurface: contextSurface ?? this.contextSurface,
      suspendedSurface: suspendedSurface == _unset
          ? this.suspendedSurface
          : suspendedSurface as MapContextSurface?,
      surfaceRevision: surfaceRevision ?? this.surfaceRevision,
      selectedSubjectType: selectedSubjectType == _unset
          ? this.selectedSubjectType
          : selectedSubjectType as String?,
      selectedClusterId: selectedClusterId == _unset
          ? this.selectedClusterId
          : selectedClusterId as String?,
      tutorial: tutorial ?? this.tutorial,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MapUiStateSnapshot &&
        other.markerSelection == markerSelection &&
        other.contextSurface == contextSurface &&
        other.suspendedSurface == suspendedSurface &&
        other.surfaceRevision == surfaceRevision &&
        other.selectedSubjectType == selectedSubjectType &&
        other.selectedClusterId == selectedClusterId &&
        other.tutorial == tutorial;
  }

  @override
  int get hashCode => Object.hash(
        markerSelection,
        contextSurface,
        suspendedSurface,
        surfaceRevision,
        selectedSubjectType,
        selectedClusterId,
        tutorial,
      );
}

@immutable
class MapMarkerSelectionState {
  const MapMarkerSelectionState({
    this.selectionToken = 0,
    this.selectedMarkerId,
    this.selectedMarker,
    this.stackedMarkers = const <ArtMarker>[],
    this.stackIndex = 0,
    this.selectedAt,
  });

  final int selectionToken;
  final String? selectedMarkerId;
  final ArtMarker? selectedMarker;
  final List<ArtMarker> stackedMarkers;
  final int stackIndex;
  final DateTime? selectedAt;

  bool get hasRenderableSelection =>
      selectedMarkerId != null &&
      selectedMarkerId!.trim().isNotEmpty &&
      selectedMarker != null &&
      selectedMarker!.id == selectedMarkerId;

  bool get hasSelection => hasRenderableSelection;

  MapMarkerSelectionState copyWith({
    int? selectionToken,
    Object? selectedMarkerId = _unset,
    Object? selectedMarker = _unset,
    List<ArtMarker>? stackedMarkers,
    int? stackIndex,
    Object? selectedAt = _unset,
  }) {
    return MapMarkerSelectionState(
      selectionToken: selectionToken ?? this.selectionToken,
      selectedMarkerId: selectedMarkerId == _unset
          ? this.selectedMarkerId
          : selectedMarkerId as String?,
      selectedMarker: selectedMarker == _unset
          ? this.selectedMarker
          : selectedMarker as ArtMarker?,
      stackedMarkers: stackedMarkers ?? this.stackedMarkers,
      stackIndex: stackIndex ?? this.stackIndex,
      selectedAt:
          selectedAt == _unset ? this.selectedAt : selectedAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MapMarkerSelectionState &&
        other.selectionToken == selectionToken &&
        other.selectedMarkerId == selectedMarkerId &&
        other.selectedMarker == selectedMarker &&
        listEquals(other.stackedMarkers, stackedMarkers) &&
        other.stackIndex == stackIndex &&
        other.selectedAt == selectedAt;
  }

  @override
  int get hashCode => Object.hash(
        selectionToken,
        selectedMarkerId,
        selectedMarker,
        Object.hashAll(stackedMarkers),
        stackIndex,
        selectedAt,
      );
}

@immutable
class MapTutorialState {
  const MapTutorialState({
    this.show = false,
    this.index = 0,
  });

  final bool show;
  final int index;

  MapTutorialState copyWith({
    bool? show,
    int? index,
  }) {
    return MapTutorialState(
      show: show ?? this.show,
      index: index ?? this.index,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MapTutorialState &&
        other.show == show &&
        other.index == index;
  }

  @override
  int get hashCode => Object.hash(show, index);
}
