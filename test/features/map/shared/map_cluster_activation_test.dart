import 'package:art_kubus/features/map/shared/map_cluster_activation.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/utils/grid_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _marker(String id, double latitude, double longitude) {
  return ArtMarker(
    id: id,
    name: id,
    description: '',
    position: LatLng(latitude, longitude),
    type: ArtMarkerType.artwork,
    createdBy: 'test',
    createdAt: DateTime.utc(2025),
  );
}

void main() {
  test('resolves members and targets the first child split', () {
    final markers = <ArtMarker>[
      _marker('a', 46.0500, 14.5000),
      _marker('b', 46.0508, 14.5008),
      _marker('outside', -33.8688, 151.2093),
    ];
    int level(double zoom) => zoom < 11 ? 2 : 20;
    final anchor = GridUtils.gridCellForLevel(markers.first.position, 2);

    final plan = resolveKubusClusterActivationPlan(
      markers: markers,
      clusterFeatureId: 'cluster:${anchor.anchorKey}',
      clusterIdPrefix: 'cluster:',
      currentZoom: 10,
      maxZoom: 18,
      gridLevelForZoom: level,
    );

    expect(plan, isNotNull);
    expect(plan!.memberIds, <String>{'a', 'b'});
    expect(plan.targetZoom, 11.25);
    expect(plan.center.latitude, closeTo(46.0504, 0.000001));
    expect(plan.southwest.latitude, 46.05);
    expect(plan.northeast.longitude, 14.5008);
  });

  test('caps travel when children do not split within the search window', () {
    final markers = <ArtMarker>[
      _marker('a', 46.05, 14.5),
      _marker('b', 46.05, 14.5),
    ];
    int level(double zoom) => 8;
    final anchor = GridUtils.gridCellForLevel(markers.first.position, 8);

    final plan = resolveKubusClusterActivationPlan(
      markers: markers,
      clusterFeatureId: 'cluster:${anchor.anchorKey}',
      clusterIdPrefix: 'cluster:',
      currentZoom: 17.5,
      maxZoom: 18,
      gridLevelForZoom: level,
    );

    expect(plan, isNotNull);
    expect(plan!.targetZoom, 18);
  });

  test('rejects unrelated or singleton features', () {
    final marker = _marker('a', 46.05, 14.5);
    int level(double zoom) => 8;
    final anchor = GridUtils.gridCellForLevel(marker.position, 8);

    expect(
      resolveKubusClusterActivationPlan(
        markers: <ArtMarker>[marker],
        clusterFeatureId: 'cluster:${anchor.anchorKey}',
        clusterIdPrefix: 'cluster:',
        currentZoom: 10,
        maxZoom: 18,
        gridLevelForZoom: level,
      ),
      isNull,
    );
  });
}
