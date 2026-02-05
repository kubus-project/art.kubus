import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/widgets/map/kubus_map_marker_geojson_builder.dart';

ArtMarker _marker(String id, LatLng pos) {
  return ArtMarker(
    id: id,
    name: 'm$id',
    description: '',
    position: pos,
    type: ArtMarkerType.artwork,
    createdAt: DateTime(2024, 1, 1),
    createdBy: 'tester',
  );
}

void main() {
  test('kubusBuildMarkerFeatureList calls builders based on clustering', () async {
    final a = _marker('a', const LatLng(52.0, 13.0));
    final b = _marker('b', const LatLng(52.0, 13.0));

    var markerCalls = 0;
    var clusterCalls = 0;

    final features = await kubusBuildMarkerFeatureList(
      markers: [a, b],
      useClustering: true,
      zoom: 10,
      clusterGridLevelForZoom: (_) => 20,
      sortClustersBySizeDesc: true,
      shouldAbort: () => false,
      buildMarkerFeature: (marker) async {
        markerCalls += 1;
        return <String, dynamic>{'type': 'Feature', 'id': marker.id};
      },
      buildClusterFeature: (cluster) async {
        clusterCalls += 1;
        return <String, dynamic>{
          'type': 'Feature',
          'id': 'cluster',
          'count': cluster.markers.length,
        };
      },
    );

    expect(markerCalls, 0);
    expect(clusterCalls, 1);
    expect(features, hasLength(1));
    expect(features.single['count'], 2);
  });

  test('kubusBuildMarkerFeatureList aborts early when requested', () async {
    final a = _marker('a', const LatLng(52.0, 13.0));

    final features = await kubusBuildMarkerFeatureList(
      markers: [a],
      useClustering: false,
      zoom: 10,
      clusterGridLevelForZoom: (_) => 20,
      sortClustersBySizeDesc: false,
      shouldAbort: () => true,
      buildMarkerFeature: (_) async => <String, dynamic>{'id': 'x'},
      buildClusterFeature: (_) async => <String, dynamic>{'id': 'y'},
    );

    expect(features, isEmpty);
  });
}
