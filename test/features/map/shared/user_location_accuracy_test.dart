import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('reliable heading creates one cone; invalid sensors leave only the dot',
      () {
    for (final accuracy in <double?>[
      null,
      -1,
      26,
      double.nan,
      double.infinity
    ]) {
      expect(KubusMapSourceSyncHelpers.reliableHeading(90, accuracy), isNull);
    }
    expect(KubusMapSourceSyncHelpers.reliableHeading(double.nan, 3), isNull);
    expect(KubusMapSourceSyncHelpers.reliableHeading(450, 3), 90);
    final data = KubusMapSourceSyncHelpers.pointFeatureCollection(
      featureId: 'me',
      position: const LatLng(46, 14),
      headingDegrees: 0,
    );
    final features = data['features'] as List;
    expect(features.map((feature) => feature['id']), ['me', 'me_heading']);
    final ring = features.last['geometry']['coordinates'][0] as List;
    expect(ring.first, ring.last);
    expect(ring[6][1], greaterThan(46));
    expect(ring[6][0], closeTo(14, 0.000001));
  });
  test('accuracy field uses live meters and stable location identity', () {
    final data = KubusMapSourceSyncHelpers.pointFeatureCollection(
      featureId: 'me',
      position: const LatLng(46, 14),
      accuracyMeters: 12,
    );
    final feature = (data['features'] as List).single as Map;
    expect(feature['id'], 'me');
    final properties = feature['properties'] as Map;
    expect(properties['accuracyRadiusZ0'], closeTo(0.0002207, 0.000001));
    expect((feature['geometry'] as Map)['coordinates'], [14.0, 46.0]);
  });

  test('missing or invalid accuracy never invents an accuracy field', () {
    for (final accuracy in [null, -1.0, 0.0, double.nan, double.infinity]) {
      final data = KubusMapSourceSyncHelpers.pointFeatureCollection(
        featureId: 'me',
        position: const LatLng(46, 14),
        accuracyMeters: accuracy,
      );
      final feature = (data['features'] as List).single as Map;
      expect((feature['properties'] as Map).containsKey('accuracyRadiusZ0'),
          false);
    }
  });
}
