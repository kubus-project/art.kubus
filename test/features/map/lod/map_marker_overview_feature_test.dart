import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:art_kubus/features/map/shared/map_cluster_activation.dart';
import 'package:art_kubus/models/map_marker_overview.dart';
import 'package:art_kubus/widgets/map/kubus_map_marker_features.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const node = MapMarkerOverviewNode(
    id: 'ov8:130:75',
    position: LatLng(48.2, 16.37),
    count: 400,
    dominantType: 'artwork',
    types: <String, int>{'artwork': 380, 'streetArt': 20},
  );

  Map<String, dynamic> feature() => kubusOverviewNodeFeature(
        node: node,
        colorHex: '#00bfa5',
        blankIconId: 'blank',
      );

  test('a node is a far dot that the cluster styling and taps understand', () {
    final f = feature();
    final props = f['properties'] as Map<String, dynamic>;

    expect(props['kind'], 'cluster');
    expect(props['renderMode'], 'cluster');
    expect(props['clusterCount'], 400);
    expect(props['color'], '#00bfa5');
    expect(props['icon'], 'blank');
    expect(props['lat'], 48.2);
    expect(props['lng'], 16.37);
    // The marker of an overview node is a dot at every zoom.
    expect(props['overview'], isTrue);
    // It never held the markers, so it names none.
    expect(props.containsKey('clusterMemberIds'), isFalse);
    expect(props.containsKey('sameCoordinateKey'), isFalse);

    // GeoJSON order is longitude, latitude.
    expect((f['geometry'] as Map)['coordinates'], <double>[16.37, 48.2]);
  });

  test('its id carries the cluster prefix so taps and hover treat it as one',
      () {
    final f = feature();
    final prefix = const KubusMapTapConfig().clusterIdPrefix;
    expect(f['id'], startsWith(prefix));
    expect((f['properties'] as Map)['id'], f['id']);
    expect(f['id'], 'cluster:ov8:130:75');
  });

  test(
      'activating a node has no members to open, so the controller falls back '
      'to zooming in on it', () {
    final plan = resolveKubusClusterActivationPlan(
      markers: const [],
      clusterFeatureId: feature()['id'] as String,
      clusterIdPrefix: const KubusMapTapConfig().clusterIdPrefix,
      currentZoom: 4,
      maxZoom: 18,
      gridLevelForZoom: (zoom) => zoom.floor(),
    );
    expect(plan, isNull);
  });
}
