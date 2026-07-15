import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';
import '../shared/map_marker_collision_config.dart';
import '../shared/map_marker_selection_resolver.dart';
import '../shared/map_screen_constants.dart';

@immutable
class MapTargetIntent {
  const MapTargetIntent({
    this.exactMarkerId,
    this.artworkId,
    this.subjectId,
    this.subjectType,
    this.preferredPosition,
    this.preferredLabel,
    this.minZoom = 16,
  });

  final String? exactMarkerId;
  final String? artworkId;
  final String? subjectId;
  final String? subjectType;
  final LatLng? preferredPosition;
  final String? preferredLabel;
  final double minZoom;

  String get markerId => _normalized(exactMarkerId);
  LatLng? get center => preferredPosition;
  double get zoom => minZoom;

  bool get hasIdentity =>
      _normalized(exactMarkerId).isNotEmpty ||
      _normalized(artworkId).isNotEmpty ||
      _normalized(subjectId).isNotEmpty;

  String get identityKey => <String>[
        _normalized(exactMarkerId),
        _normalized(artworkId),
        _normalized(subjectId),
        _normalized(subjectType).toLowerCase(),
      ].join('|');

  static String _normalized(String? value) => value?.trim() ?? '';
}

enum MapTargetPhase {
  idle,
  waitingForMap,
  resolving,
  movingCamera,
  waitingForOverlay,
  completed,
}

enum MapTargetResult {
  overlayOpened,
  coordinatesOnly,
  notFound,
  cancelled,
  superseded,
}

typedef MapTargetTerminalCallback = void Function(
  MapTargetIntent intent,
  MapTargetResult result,
);

/// Resolves a direct map target only when the map, style, and target data are
/// explicitly ready. No timer or fixed-delay retry participates in readiness.
class MapTargetCoordinator {
  MapTargetCoordinator({
    required List<ArtMarker> Function() loadedMarkers,
    required Future<ArtMarker?> Function(String markerId) fetchMarkerById,
    required Future<List<ArtMarker>> Function(String artworkId)
        fetchMarkersByArtwork,
    required Future<void> Function(LatLng position) loadMarkersAround,
    required void Function(List<ArtMarker> markers) mergeMarkers,
    required Future<void> Function(LatLng position, double zoom) moveCamera,
    required void Function(ArtMarker marker) selectMarker,
    required void Function(String? markerId) setPinnedMarker,
    required void Function(MapTargetIntent intent, MapTargetResult result)
        showFallback,
    required MapTargetTerminalCallback onTerminal,
  })  : _loadedMarkers = loadedMarkers,
        _fetchMarkerById = fetchMarkerById,
        _fetchMarkersByArtwork = fetchMarkersByArtwork,
        _loadMarkersAround = loadMarkersAround,
        _mergeMarkers = mergeMarkers,
        _moveCamera = moveCamera,
        _selectMarker = selectMarker,
        _setPinnedMarker = setPinnedMarker,
        _showFallback = showFallback,
        _onTerminal = onTerminal;

  final List<ArtMarker> Function() _loadedMarkers;
  final Future<ArtMarker?> Function(String markerId) _fetchMarkerById;
  final Future<List<ArtMarker>> Function(String artworkId)
      _fetchMarkersByArtwork;
  final Future<void> Function(LatLng position) _loadMarkersAround;
  final void Function(List<ArtMarker> markers) _mergeMarkers;
  final Future<void> Function(LatLng position, double zoom) _moveCamera;
  final void Function(ArtMarker marker) _selectMarker;
  final void Function(String? markerId) _setPinnedMarker;
  final void Function(MapTargetIntent intent, MapTargetResult result)
      _showFallback;
  final MapTargetTerminalCallback _onTerminal;

  MapTargetIntent? _pending;
  MapTargetPhase _phase = MapTargetPhase.idle;
  bool _mapControllerReady = false;
  bool _styleReady = false;
  bool _driving = false;
  bool _driveAgain = false;
  bool _disposed = false;
  int _generation = 0;
  String? _awaitingOverlayMarkerId;
  String? _pinnedMarkerId;
  Completer<MapTargetResult>? _completion;

  MapTargetIntent? get pending => _pending;
  MapTargetPhase get phase => _phase;
  String? get pinnedMarkerId => _pinnedMarkerId;
  String? get awaitingOverlayMarkerId => _awaitingOverlayMarkerId;

  static double focusZoomFor(MapTargetIntent intent) => math.max(
        intent.minZoom,
        math.max(
          MapScreenConstants.clusterMaxZoom + 1,
          MapMarkerCollisionConfig.spiderfyAutoExpandZoom,
        ),
      );

  Future<MapTargetResult> submit(MapTargetIntent intent) {
    if (_disposed || !intent.hasIdentity) {
      return Future<MapTargetResult>.value(MapTargetResult.notFound);
    }
    final previous = _pending;
    if (previous != null) {
      _finish(previous, MapTargetResult.superseded, clearPin: true);
    } else {
      _clearPin();
    }
    _pending = intent;
    _completion = Completer<MapTargetResult>();
    _awaitingOverlayMarkerId = null;
    _phase = MapTargetPhase.waitingForMap;
    _generation += 1;
    _requestDrive();
    return _completion!.future;
  }

  void setMapControllerReady(bool ready) {
    if (_disposed || _mapControllerReady == ready) return;
    _mapControllerReady = ready;
    if (!ready) _styleReady = false;
    _requestDrive();
  }

  void setStyleReady(bool ready) {
    if (_disposed || _styleReady == ready) return;
    _styleReady = ready;
    _requestDrive();
  }

  void notifyMarkersChanged() => _requestDrive();

  void acknowledgeOverlay(String markerId) {
    if (_disposed || _phase != MapTargetPhase.waitingForOverlay) return;
    final normalizedId = markerId.trim();
    if (normalizedId.isEmpty || normalizedId != _awaitingOverlayMarkerId) {
      return;
    }
    final intent = _pending;
    if (intent == null) return;
    _finish(intent, MapTargetResult.overlayOpened, clearPin: false);
  }

  void selectionChanged(String? markerId) {
    if (_disposed) return;
    final normalizedId = markerId?.trim() ?? '';
    final expectedId = _awaitingOverlayMarkerId ?? _pinnedMarkerId;
    if (expectedId == null) return;
    if (normalizedId == expectedId) return;

    final intent = _pending;
    if (intent != null) {
      _finish(intent, MapTargetResult.cancelled, clearPin: true);
    } else {
      _clearPin();
    }
  }

  void cancel() {
    if (_disposed) return;
    final intent = _pending;
    if (intent != null) {
      _finish(intent, MapTargetResult.cancelled, clearPin: true);
    } else {
      _clearPin();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _pending = null;
    final completion = _completion;
    _completion = null;
    _awaitingOverlayMarkerId = null;
    if (completion != null && !completion.isCompleted) {
      completion.complete(MapTargetResult.cancelled);
    }
    _clearPin();
  }

  void _requestDrive() {
    if (_disposed || _pending == null) return;
    if (_driving) {
      _driveAgain = true;
      return;
    }
    unawaited(_drive());
  }

  Future<void> _drive() async {
    if (_disposed || _driving) return;
    _driving = true;
    MapTargetIntent? activeIntent;
    int? activeGeneration;
    try {
      do {
        _driveAgain = false;
        final intent = _pending;
        if (intent == null || _disposed) return;
        final generation = _generation;
        activeIntent = intent;
        activeGeneration = generation;

        if (!_mapControllerReady || !_styleReady) {
          _phase = MapTargetPhase.waitingForMap;
          return;
        }
        if (_phase == MapTargetPhase.waitingForOverlay) return;

        _phase = MapTargetPhase.resolving;
        var candidate = _resolve(intent, _loadedMarkers());
        if (candidate == null) {
          final fetched = <ArtMarker>[];
          final markerId = intent.exactMarkerId?.trim() ?? '';
          if (markerId.isNotEmpty) {
            final marker = await _fetchMarkerById(markerId);
            if (!_isCurrent(intent, generation)) return;
            if (marker != null) fetched.add(marker);
          }

          final artworkId = intent.artworkId?.trim() ?? '';
          if (artworkId.isNotEmpty) {
            fetched.addAll(await _fetchMarkersByArtwork(artworkId));
            if (!_isCurrent(intent, generation)) return;
          }

          if (fetched.isNotEmpty) {
            _mergeMarkers(_dedupeValidMarkers(fetched));
            if (!_isCurrent(intent, generation)) return;
          }
          candidate = _resolve(intent, _loadedMarkers());
        }

        if (candidate == null && intent.preferredPosition != null) {
          await _loadMarkersAround(intent.preferredPosition!);
          if (!_isCurrent(intent, generation)) return;
          candidate = _resolve(intent, _loadedMarkers());
        }

        if (candidate == null) {
          final position = intent.preferredPosition;
          if (position != null) {
            _phase = MapTargetPhase.movingCamera;
            await _moveCamera(position, intent.minZoom);
            if (!_isCurrent(intent, generation)) return;
            _showFallback(intent, MapTargetResult.coordinatesOnly);
            _finish(intent, MapTargetResult.coordinatesOnly, clearPin: true);
          } else {
            _showFallback(intent, MapTargetResult.notFound);
            _finish(intent, MapTargetResult.notFound, clearPin: true);
          }
          return;
        }

        _pin(candidate.id);
        _phase = MapTargetPhase.movingCamera;
        await _moveCamera(candidate.position, focusZoomFor(intent));
        if (!_isCurrent(intent, generation)) return;

        _awaitingOverlayMarkerId = candidate.id;
        _phase = MapTargetPhase.waitingForOverlay;
        _selectMarker(candidate);
      } while (_driveAgain);
    } catch (_) {
      final intent = activeIntent;
      final generation = activeGeneration;
      if (intent != null &&
          generation != null &&
          _isCurrent(intent, generation)) {
        try {
          _showFallback(intent, MapTargetResult.notFound);
        } catch (_) {}
        _finish(intent, MapTargetResult.notFound, clearPin: true);
      }
    } finally {
      _driving = false;
      if (_driveAgain && !_disposed && _pending != null) {
        _requestDrive();
      }
    }
  }

  ArtMarker? _resolve(MapTargetIntent intent, Iterable<ArtMarker> markers) {
    return resolveBestMarkerCandidate(
      markers.where((marker) => marker.hasValidPosition),
      exactMarkerId: intent.exactMarkerId,
      artworkId: intent.artworkId,
      subjectId: intent.subjectId,
      subjectType: intent.subjectType,
      preferredLabel: intent.preferredLabel,
      preferredPosition: intent.preferredPosition,
    );
  }

  bool _isCurrent(MapTargetIntent intent, int generation) =>
      !_disposed && identical(_pending, intent) && _generation == generation;

  List<ArtMarker> _dedupeValidMarkers(Iterable<ArtMarker> markers) {
    final byId = <String, ArtMarker>{};
    for (final marker in markers) {
      if (marker.id.trim().isEmpty || !marker.hasValidPosition) continue;
      byId[marker.id] = marker;
    }
    return byId.values.toList(growable: false);
  }

  void _pin(String markerId) {
    if (_pinnedMarkerId == markerId) return;
    _pinnedMarkerId = markerId;
    _setPinnedMarker(markerId);
  }

  void _clearPin() {
    if (_pinnedMarkerId == null) return;
    _pinnedMarkerId = null;
    _setPinnedMarker(null);
  }

  void _finish(
    MapTargetIntent intent,
    MapTargetResult result, {
    required bool clearPin,
  }) {
    if (!identical(_pending, intent)) return;
    _pending = null;
    final completion = _completion;
    _completion = null;
    _awaitingOverlayMarkerId = null;
    _phase = MapTargetPhase.completed;
    if (clearPin) _clearPin();
    if (completion != null && !completion.isCompleted) {
      completion.complete(result);
    }
    try {
      _onTerminal(intent, result);
    } catch (_) {}
  }
}
