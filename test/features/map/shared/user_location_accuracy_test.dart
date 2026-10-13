import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
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
