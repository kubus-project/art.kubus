import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../config/config.dart';
import '../../../models/art_marker.dart';
import '../../../models/event.dart';
import '../../../models/exhibition.dart';
import '../shared/map_marker_overlay_presentation.dart';

@immutable
class MapMarkerLinkedSubjectSnapshot {
  const MapMarkerLinkedSubjectSnapshot({this.event, this.exhibition});

  final KubusEvent? event;
  final Exhibition? exhibition;
}

/// Owns the selection side effect that hydrates event and exhibition subjects
/// behind the shared marker quick card.
///
/// Both map screens delegate selection to a single instance of this
/// coordinator instead of duplicating the hydration lifecycle: request
/// de-duplication, the "is this marker still selected" guard and the follow-up
/// rebuild request all live here, so the behaviour stays synchronized between
/// layouts and is testable without a real MapLibre controller.
class MapMarkerLinkedSubjectCoordinator {
  MapMarkerLinkedSubjectCoordinator({
    required KubusEvent? Function(String id) cachedEvent,
    required Exhibition? Function(String id) cachedExhibition,
    required bool Function(String id) isEventDetailHydrated,
    required bool Function(String id) isExhibitionDetailHydrated,
    required Future<KubusEvent?> Function(String id) fetchEvent,
    required Future<Exhibition?> Function(String id) fetchExhibition,
    required String? Function() selectedMarkerId,
    required VoidCallback onSubjectHydrated,
  })  : _cachedEvent = cachedEvent,
        _cachedExhibition = cachedExhibition,
        _isEventDetailHydrated = isEventDetailHydrated,
        _isExhibitionDetailHydrated = isExhibitionDetailHydrated,
        _fetchEvent = fetchEvent,
        _fetchExhibition = fetchExhibition,
        _selectedMarkerId = selectedMarkerId,
        _onSubjectHydrated = onSubjectHydrated;

  final KubusEvent? Function(String id) _cachedEvent;
  final Exhibition? Function(String id) _cachedExhibition;
  final bool Function(String id) _isEventDetailHydrated;
  final bool Function(String id) _isExhibitionDetailHydrated;
  final Future<KubusEvent?> Function(String id) _fetchEvent;
  final Future<Exhibition?> Function(String id) _fetchExhibition;
  final String? Function() _selectedMarkerId;
  final VoidCallback _onSubjectHydrated;

  final Map<String, Future<bool>> _inFlight = <String, Future<bool>>{};
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @visibleForTesting
  int get inFlightCount => _inFlight.length;

  /// Whatever the providers already hold for this marker's linked subject.
  ///
  /// Cheap and synchronous: safe to call from a build method.
  MapMarkerLinkedSubjectSnapshot resolveCached(ArtMarker marker) {
    switch (resolveMarkerOverlayLinkedSubjectKind(marker)) {
      case MapMarkerOverlayLinkedSubjectKind.event:
        final id = _eventIdFor(marker);
        return MapMarkerLinkedSubjectSnapshot(
          event: id.isEmpty ? null : _cachedEvent(id),
        );
      case MapMarkerOverlayLinkedSubjectKind.exhibition:
        final id = _exhibitionIdFor(marker);
        return MapMarkerLinkedSubjectSnapshot(
          exhibition: id.isEmpty ? null : _cachedExhibition(id),
        );
      case MapMarkerOverlayLinkedSubjectKind.none:
      case MapMarkerOverlayLinkedSubjectKind.artwork:
      case MapMarkerOverlayLinkedSubjectKind.institution:
      case MapMarkerOverlayLinkedSubjectKind.group:
      case MapMarkerOverlayLinkedSubjectKind.misc:
        return const MapMarkerLinkedSubjectSnapshot();
    }
  }

  /// Entry point for both map screens' `onSelectionChanged` handler.
  ///
  /// Fire and forget: the coordinator requests a rebuild itself once the
  /// linked subject arrives and the marker is still selected.
  void selectionChanged(ArtMarker? marker) {
    if (_disposed || marker == null) return;
    unawaited(hydrate(marker));
  }

  /// Loads the marker's linked subject detail when the cached entry is missing
  /// or only carries list-shaped fields, then requests a rebuild.
  ///
  /// Resolves to whether a detail load actually happened.
  @visibleForTesting
  Future<bool> hydrate(ArtMarker marker) async {
    if (_disposed) return false;

    final kind = resolveMarkerOverlayLinkedSubjectKind(marker);
    final String id;
    final Future<bool> Function() load;

    switch (kind) {
      case MapMarkerOverlayLinkedSubjectKind.event:
        id = _eventIdFor(marker);
        if (id.isEmpty ||
            !AppConfig.isFeatureEnabled('events') ||
            _isEventDetailHydrated(id)) {
          return false;
        }
        load = () async => await _fetchEvent(id) != null;
      case MapMarkerOverlayLinkedSubjectKind.exhibition:
        id = _exhibitionIdFor(marker);
        if (id.isEmpty ||
            !AppConfig.isFeatureEnabled('exhibitions') ||
            _isExhibitionDetailHydrated(id)) {
          return false;
        }
        load = () async => await _fetchExhibition(id) != null;
      case MapMarkerOverlayLinkedSubjectKind.none:
      case MapMarkerOverlayLinkedSubjectKind.artwork:
      case MapMarkerOverlayLinkedSubjectKind.institution:
      case MapMarkerOverlayLinkedSubjectKind.group:
      case MapMarkerOverlayLinkedSubjectKind.misc:
        return false;
    }

    final key = '${kind.name}:$id';
    final hydrated = await (_inFlight[key] ??= _guarded(key, load));

    if (!hydrated || _disposed) return hydrated;
    if (_selectedMarkerId() == marker.id) {
      _onSubjectHydrated();
    }
    return hydrated;
  }

  void dispose() {
    _disposed = true;
    _inFlight.clear();
  }

  Future<bool> _guarded(String key, Future<bool> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return false;
    } finally {
      _inFlight.remove(key);
    }
  }

  String _eventIdFor(ArtMarker marker) => (marker.subjectId ?? '').trim();

  String _exhibitionIdFor(ArtMarker marker) =>
      (marker.resolvedExhibitionSummary?.id ?? marker.subjectId ?? '').trim();
}
