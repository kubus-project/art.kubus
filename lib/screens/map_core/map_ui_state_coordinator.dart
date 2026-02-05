import 'package:flutter/foundation.dart';

import '../../models/art_marker.dart';

const Object _unset = Object();

/// Canonical UI state machine for map screens (mobile + desktop).
///
/// This coordinator owns *UI state only* (selection, overlay/panel openness).
/// It intentionally contains:
/// - no BuildContext
/// - no provider reads
/// - no MapLibre controller calls
///
/// Screens remain responsible for executing side effects (navigation, fetches,
/// map controller actions) in response to state changes.
class MapUiStateCoordinator {
  MapUiStateCoordinator();

  final ValueNotifier<MapUiStateSnapshot> state =
      ValueNotifier<MapUiStateSnapshot>(const MapUiStateSnapshot());

  MapUiStateSnapshot get value => state.value;

  void dispose() {
    state.dispose();
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
    final next = value.copyWith(
      markerSelection: value.markerSelection.copyWith(
        selectionToken: selectionToken,
        selectedMarkerId: selectedMarkerId,
        selectedMarker: selectedMarker,
        stackedMarkers: stackedMarkers,
        stackIndex: stackIndex,
        selectedAt: selectedAt,
      ),
    );
    if (next == value) return;
    state.value = next;
  }

  void dismissMarkerSelection({int? nextSelectionToken}) {
    final next = value.copyWith(
      markerSelection: value.markerSelection.copyWith(
        selectionToken: nextSelectionToken ?? (value.markerSelection.selectionToken + 1),
        selectedMarkerId: null,
        selectedMarker: null,
        stackedMarkers: const <ArtMarker>[],
        stackIndex: 0,
        selectedAt: null,
      ),
    );
    state.value = next;
  }

  // --- Panel / overlay openness ---

  void setMarkerOverlayOpen(bool open) {
    if (value.overlayOpen == open) return;
    state.value = value.copyWith(overlayOpen: open);
  }

  void setSidePanelOpen(bool open) {
    if (value.panelOpen == open) return;
    state.value = value.copyWith(panelOpen: open);
  }

  void setDiscoveryOpen(bool open) {
    if (value.discoveryOpen == open) return;
    state.value = value.copyWith(discoveryOpen: open);
  }

  void setFiltersOpen(bool open) {
    if (value.filtersOpen == open) return;
    state.value = value.copyWith(filtersOpen: open);
  }

  void setNearbyOpen(bool open) {
    if (value.nearbyOpen == open) return;
    state.value = value.copyWith(nearbyOpen: open);
  }

  // --- Tutorial ---

  void setTutorial({required bool show, required int index}) {
    final nextTutorial = value.tutorial.copyWith(show: show, index: index);
    if (nextTutorial == value.tutorial) return;
    state.value = value.copyWith(tutorial: nextTutorial);
  }
}

@immutable
class MapUiStateSnapshot {
  const MapUiStateSnapshot({
    this.markerSelection = const MapMarkerSelectionState(),
    this.overlayOpen = false,
    this.panelOpen = false,
    this.discoveryOpen = false,
    this.filtersOpen = false,
    this.nearbyOpen = false,
    this.selectedSubjectType,
    this.selectedClusterId,
    this.tutorial = const MapTutorialState(),
  });

  final MapMarkerSelectionState markerSelection;

  /// Marker info overlay open state (card / overlay layer).
  final bool overlayOpen;

  /// Side panel open state (desktop details panel).
  final bool panelOpen;

  final bool discoveryOpen;
  final bool filtersOpen;
  final bool nearbyOpen;

  /// Optional cross-platform identifier for what kind of subject is selected.
  ///
  /// Example values: 'artwork', 'institution', 'event', 'exhibition'.
  final String? selectedSubjectType;

  /// Optional identifier for selected cluster (if cluster selection is modeled).
  final String? selectedClusterId;

  final MapTutorialState tutorial;

  MapUiStateSnapshot copyWith({
    MapMarkerSelectionState? markerSelection,
    bool? overlayOpen,
    bool? panelOpen,
    bool? discoveryOpen,
    bool? filtersOpen,
    bool? nearbyOpen,
    Object? selectedSubjectType = _unset,
    Object? selectedClusterId = _unset,
    MapTutorialState? tutorial,
  }) {
    return MapUiStateSnapshot(
      markerSelection: markerSelection ?? this.markerSelection,
      overlayOpen: overlayOpen ?? this.overlayOpen,
      panelOpen: panelOpen ?? this.panelOpen,
      discoveryOpen: discoveryOpen ?? this.discoveryOpen,
      filtersOpen: filtersOpen ?? this.filtersOpen,
      nearbyOpen: nearbyOpen ?? this.nearbyOpen,
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
        other.overlayOpen == overlayOpen &&
        other.panelOpen == panelOpen &&
        other.discoveryOpen == discoveryOpen &&
        other.filtersOpen == filtersOpen &&
        other.nearbyOpen == nearbyOpen &&
        other.selectedSubjectType == selectedSubjectType &&
        other.selectedClusterId == selectedClusterId &&
        other.tutorial == tutorial;
  }

  @override
  int get hashCode => Object.hash(
        markerSelection,
        overlayOpen,
        panelOpen,
        discoveryOpen,
        filtersOpen,
        nearbyOpen,
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

  bool get hasSelection => selectedMarkerId != null;

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
    return other is MapTutorialState && other.show == show && other.index == index;
  }

  @override
  int get hashCode => Object.hash(show, index);
}
