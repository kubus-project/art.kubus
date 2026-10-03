import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/art_marker.dart';
import '../filters/map_filter_state.dart';

/// Where the visitor left the camera.
@immutable
class KubusMapSessionCamera {
  const KubusMapSessionCamera({required this.center, required this.zoom});

  final LatLng center;
  final double zoom;
}

/// What the map remembers while the app runs, so a layout change does not send
/// the visitor back to the opening world.
///
/// The phone and wide layouts are two screens, each with its own controller. A
/// rotation, a resizable window or a foldable crossing the breakpoint swaps one
/// for the other, which used to recreate the map at the locale opening: camera,
/// search text, filters and the selected marker were all lost. Both screens
/// write here and the next screen reads it before it first renders, so the new
/// map opens where the old one was.
///
/// This is session memory, not persistence: it lives in the widget tree's
/// provider and is gone when the app is. It holds no renderer, controller or
/// selection logic; selection is restored through the screen's own marker-tap
/// path so there is still exactly one selection owner.
class KubusMapSessionMemory {
  KubusMapSessionMemory() {
    _live.add(this);
  }

  static final Set<KubusMapSessionMemory> _live = <KubusMapSessionMemory>{};

  /// Sign-out: nothing the previous account looked at (camera, filters, search,
  /// a selected marker) may reopen for the next one on this device.
  static void clearAll() {
    for (final memory in _live) {
      memory.clear();
    }
  }

  void dispose() => _live.remove(this);

  KubusMapSessionCamera? _camera;
  KubusMapFilterState _filters = KubusMapFilterState.defaults();
  String _query = '';
  ArtMarker? _selectedMarker;

  KubusMapSessionCamera? get camera => _camera;
  KubusMapFilterState get filters => _filters;
  String get query => _query;
  ArtMarker? get selectedMarker => _selectedMarker;

  /// Whether a previous map screen left anything worth restoring.
  bool get hasState => _camera != null;

  /// Whether an entry may adopt the remembered state.
  ///
  /// An explicit target (an initial centre or zoom, a deep or internal marker
  /// target, a walking navigation intent) is more specific than anything the
  /// visitor happened to leave behind, so it always wins over memory.
  bool canRestore({
    required bool hasExplicitCenterOrZoom,
    required bool hasDirectTarget,
    required bool hasWalkingIntent,
  }) =>
      hasState &&
      !hasExplicitCenterOrZoom &&
      !hasDirectTarget &&
      !hasWalkingIntent;

  void rememberCamera(LatLng center, double zoom) {
    if (!center.latitude.isFinite ||
        !center.longitude.isFinite ||
        !zoom.isFinite) {
      return;
    }
    _camera = KubusMapSessionCamera(center: center, zoom: zoom);
  }

  void rememberFilters(KubusMapFilterState filters) => _filters = filters;

  void rememberQuery(String query) => _query = query;

  /// A null marker records that the visitor dismissed the selection.
  void rememberSelection(ArtMarker? marker) => _selectedMarker = marker;

  /// Test and sign-out seam.
  void clear() {
    _camera = null;
    _filters = KubusMapFilterState.defaults();
    _query = '';
    _selectedMarker = null;
  }
}
