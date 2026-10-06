import 'package:flutter/foundation.dart';

import '../../../models/map_marker_overview.dart';
import '../../../utils/geo_bounds.dart';
import '../../../utils/map_viewport_utils.dart';

/// What a [KubusMapOverviewController.refresh] decided.
enum KubusMapOverviewRefresh {
  /// The camera is close enough for detailed markers; the overview is off and
  /// the caller should run its normal detailed fetch.
  detailed,

  /// The overview is on and already covers the viewport at this zoom.
  unchanged,

  /// A new overview was fetched and is now current.
  applied,

  /// A newer viewport superseded this request; its answer was discarded.
  superseded,

  /// The overview could not be fetched (an older backend, an outage). The
  /// overview is off and the caller falls back to the detailed fetch.
  unavailable,
}

/// Decides, per camera settle, whether the map shows the server's low-zoom
/// overview or detailed markers, and keeps the current overview.
///
/// At world and region zoom a handful of nearest-first detailed markers cannot
/// represent the dataset, so the far map is drawn from exact aggregate nodes
/// (see the backend's `/api/art-markers/overview`). From [exitZoom] the normal
/// detailed fetch and client clustering take over. The switch has hysteresis so
/// a camera hovering around the threshold does not flip modes (and refetch)
/// every settle.
///
/// The controller owns no widgets and no timers other than the injected clock's
/// failure backoff, which only spaces retries of a failing endpoint.
class KubusMapOverviewController {
  KubusMapOverviewController({
    required Future<MapMarkerOverview> Function(GeoBounds bounds, double zoom)
        fetch,
    DateTime Function()? clock,
  })  : _fetch = fetch,
        _clock = clock ?? DateTime.now;

  /// Overview below this zoom; detailed markers from it.
  static const double exitZoom = 8.0;

  /// When detailed markers are showing, the overview comes back only below this
  /// zoom (a little under [exitZoom]).
  static const double reenterZoom = 7.7;

  /// Failed overview fetches are not retried for this long.
  static const Duration failureBackoff = Duration(seconds: 20);

  final Future<MapMarkerOverview> Function(GeoBounds bounds, double zoom)
      _fetch;
  final DateTime Function() _clock;

  MapMarkerOverview? _overview;
  GeoBounds? _loadedBounds;
  int? _loadedLevel;
  bool _active = false;
  int _generation = 0;
  DateTime? _backoffUntil;

  // The request in flight, so concurrent settles over the same area and grid
  // level (a cold start raises several) share one fetch instead of each asking.
  Future<MapMarkerOverview>? _inFlight;
  GeoBounds? _inFlightBounds;
  int? _inFlightLevel;

  /// The current overview, or null when detailed markers are showing.
  MapMarkerOverview? get overview => _active ? _overview : null;

  /// Whether the map is currently drawn from the overview.
  bool get isActive => _active && _overview != null;

  /// The grid level a zoom maps to (the backend's half-step levels), so a refetch
  /// happens when the level changes, not on every fractional zoom.
  static int levelForZoom(double zoom) =>
      ((zoom.isFinite ? zoom : 0) * 2).floor().clamp(0, 24);

  /// Whether [zoom] calls for the overview, given the current mode.
  ///
  /// [allowed] is false while a filter the overview cannot express is active
  /// (favourites, AR, discovery status, a search): those depend on per-artwork
  /// state, so the detailed markers are used instead.
  bool wantsOverviewAt(double zoom, {bool allowed = true}) {
    if (!allowed || !zoom.isFinite) return false;
    return zoom < (_active ? exitZoom : reenterZoom);
  }

  /// Whether a camera settling at [zoom] over [visible] needs a [refresh]: the
  /// mode must change, or the overview is on and no longer covers this viewport
  /// at this grid level. A pure check, so a caller can decide before it does any
  /// work.
  bool needsRefresh({
    required GeoBounds visible,
    required double zoom,
    bool allowed = true,
  }) {
    final wants = wantsOverviewAt(zoom, allowed: allowed);
    if (wants != _active) return true;
    if (!wants) return false;
    final loaded = _loadedBounds;
    return _overview == null ||
        _loadedLevel != levelForZoom(zoom) ||
        loaded == null ||
        !MapViewportUtils.containsBounds(loaded, visible);
  }

  /// Settles the mode for a camera at [zoom] over [visible], fetching a
  /// (padded) [queryBounds] overview when it is needed. [force] refetches even
  /// when the current overview covers the viewport.
  Future<KubusMapOverviewRefresh> refresh({
    required GeoBounds visible,
    required GeoBounds queryBounds,
    required double zoom,
    bool force = false,
    bool allowed = true,
  }) async {
    if (!wantsOverviewAt(zoom, allowed: allowed)) {
      deactivate();
      return KubusMapOverviewRefresh.detailed;
    }

    final backoff = _backoffUntil;
    if (backoff != null && _clock().isBefore(backoff)) {
      _active = false;
      return KubusMapOverviewRefresh.unavailable;
    }

    final level = levelForZoom(zoom);
    if (!force &&
        _active &&
        _overview != null &&
        _loadedLevel == level &&
        _loadedBounds != null &&
        MapViewportUtils.containsBounds(_loadedBounds!, visible)) {
      return KubusMapOverviewRefresh.unchanged;
    }

    final shared = _inFlight;
    final sharesInFlight = shared != null &&
        _inFlightLevel == level &&
        _inFlightBounds != null &&
        MapViewportUtils.containsBounds(_inFlightBounds!, queryBounds);
    // A shared request keeps the generation of the one that started it, so it is
    // still discarded if the camera moves on before it answers.
    final generation = sharesInFlight ? _generation : ++_generation;
    final MapMarkerOverview fetched;
    try {
      if (sharesInFlight) {
        fetched = await shared;
      } else {
        final request = _fetch(queryBounds, zoom);
        _inFlight = request;
        _inFlightBounds = queryBounds;
        _inFlightLevel = level;
        try {
          fetched = await request;
        } finally {
          if (identical(_inFlight, request)) {
            _inFlight = null;
            _inFlightBounds = null;
            _inFlightLevel = null;
          }
        }
      }
    } catch (error) {
      if (generation != _generation) return KubusMapOverviewRefresh.superseded;
      _backoffUntil = _clock().add(failureBackoff);
      _active = false;
      if (kDebugMode) {
        debugPrint('KubusMapOverviewController: overview unavailable: $error');
      }
      return KubusMapOverviewRefresh.unavailable;
    }

    // A newer viewport (or a switch back to detailed markers) happened while
    // this request was in flight: its answer describes a place the camera has
    // left, and must not replace the newer state.
    if (generation != _generation) return KubusMapOverviewRefresh.superseded;

    _backoffUntil = null;
    _overview = fetched;
    _loadedBounds = queryBounds;
    _loadedLevel = level;
    _active = true;
    return KubusMapOverviewRefresh.applied;
  }

  /// Turns the overview off (detailed markers take over). Any request still in
  /// flight is discarded when it returns.
  void deactivate() {
    _generation += 1;
    _inFlight = null;
    _inFlightBounds = null;
    _inFlightLevel = null;
    _active = false;
    _overview = null;
    _loadedBounds = null;
    _loadedLevel = null;
  }

  /// Drops the loaded overview so the next [refresh] fetches again (a filter or
  /// data change), without leaving the overview mode.
  void invalidate() {
    _loadedBounds = null;
    _loadedLevel = null;
  }
}
