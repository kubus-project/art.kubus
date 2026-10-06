import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// One node of the low-zoom map overview: an exact count of the public, active
/// markers in a projected grid cell, with their centroid and category mix. It
/// carries no marker detail; the detailed markers are fetched once the visitor
/// zooms in far enough to see them.
@immutable
class MapMarkerOverviewNode {
  const MapMarkerOverviewNode({
    required this.id,
    required this.position,
    required this.count,
    required this.dominantType,
    this.types = const <String, int>{},
    this.markerId,
  });

  /// Stable per grid cell and zoom level (`ov<level>:<cx>:<cy>`), independent of
  /// the viewport, so a node keeps its id while the visitor pans.
  final String id;
  final LatLng position;

  /// Exact number of markers the node represents.
  final int count;

  /// The most frequent marker type in the cell (the far dot's colour).
  final String dominantType;
  final Map<String, int> types;

  /// The marker's id when [count] is 1.
  final String? markerId;

  /// This node restricted to the marker types [isVisible] accepts (the map's
  /// content-layer toggles), or null when none of its markers remain. The count
  /// stays exact for what is shown; the position is the cell's centroid.
  MapMarkerOverviewNode? restrictedTo(bool Function(String type) isVisible) {
    if (types.isEmpty) return isVisible(dominantType) ? this : null;
    var visibleCount = 0;
    String? dominant;
    var dominantCount = 0;
    final kept = <String, int>{};
    for (final entry in types.entries) {
      if (!isVisible(entry.key)) continue;
      kept[entry.key] = entry.value;
      visibleCount += entry.value;
      if (entry.value > dominantCount) {
        dominantCount = entry.value;
        dominant = entry.key;
      }
    }
    if (visibleCount <= 0 || dominant == null) return null;
    if (visibleCount == count) return this;
    return MapMarkerOverviewNode(
      id: id,
      position: position,
      count: visibleCount,
      dominantType: dominant,
      types: Map<String, int>.unmodifiable(kept),
      markerId: visibleCount == 1 ? markerId : null,
    );
  }

  static MapMarkerOverviewNode? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString().trim() ?? '';
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    final count = (raw['count'] as num?)?.toInt();
    if (id.isEmpty ||
        lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        count == null ||
        count <= 0) {
      return null;
    }
    final typesRaw = raw['types'];
    final types = <String, int>{
      if (typesRaw is Map)
        for (final entry in typesRaw.entries)
          if (entry.value is num)
            entry.key.toString(): (entry.value as num).toInt(),
    };
    final markerId = raw['markerId']?.toString().trim();
    return MapMarkerOverviewNode(
      id: id,
      position: LatLng(lat, lng),
      count: count,
      dominantType: raw['dominantType']?.toString().trim().isNotEmpty == true
          ? raw['dominantType'].toString().trim()
          : 'unknown',
      types: Map<String, int>.unmodifiable(types),
      markerId: markerId == null || markerId.isEmpty ? null : markerId,
    );
  }
}

/// The overview of one viewport at one zoom: truthful aggregate nodes.
@immutable
class MapMarkerOverview {
  const MapMarkerOverview({
    required this.zoom,
    required this.level,
    required this.total,
    required this.nodes,
  });

  final double zoom;

  /// The grid level the server used (it may be coarser than the zoom asked for
  /// when the viewport was unusually large).
  final int level;

  /// Sum of the node counts: the markers the overview represents.
  final int total;
  final List<MapMarkerOverviewNode> nodes;

  static MapMarkerOverview? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final data = raw['data'];
    if (data is! List) return null;
    final nodes = <MapMarkerOverviewNode>[
      for (final item in data)
        if (MapMarkerOverviewNode.tryParse(item) case final node?) node,
    ];
    return MapMarkerOverview(
      zoom: (raw['zoom'] as num?)?.toDouble() ?? 0,
      level: (raw['level'] as num?)?.toInt() ?? 0,
      total: nodes.fold<int>(0, (sum, node) => sum + node.count),
      nodes: List<MapMarkerOverviewNode>.unmodifiable(nodes),
    );
  }
}
