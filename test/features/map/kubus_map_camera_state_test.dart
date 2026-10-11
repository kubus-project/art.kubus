import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// A move that leaves the camera where it was (MapLibre re-measuring its canvas
/// when the map becomes visible again) is not a gesture. Only a camera that
/// actually changed may dismiss an open marker card.
void main() {
  const base = KubusMapCameraState(
    center: LatLng(46.050666, 14.505665),
    zoom: 16.5,
    bearing: 0,
    pitch: 0,
  );

  KubusMapCameraState with_({
    LatLng? center,
    double? zoom,
    double? bearing,
    double? pitch,
  }) =>
      KubusMapCameraState(
        center: center ?? base.center,
        zoom: zoom ?? base.zoom,
        bearing: bearing ?? base.bearing,
        pitch: pitch ?? base.pitch,
      );

  test('an identical camera is not a change', () {
    expect(with_().differsFrom(base), isFalse);
  });

  test('rounding-level jitter is not a change', () {
    expect(
      with_(center: const LatLng(46.050666 + 1e-9, 14.505665))
          .differsFrom(base),
      isFalse,
    );
    expect(with_(zoom: 16.5 + 1e-6).differsFrom(base), isFalse);
    expect(with_(bearing: 1e-5, pitch: -1e-5).differsFrom(base), isFalse);
  });

  test('real movement in any dimension is a change', () {
    expect(
      with_(center: const LatLng(46.050666, 14.505665 + 1e-4))
          .differsFrom(base),
      isTrue,
    );
    expect(
      with_(center: const LatLng(46.050666 + 1e-4, 14.505665))
          .differsFrom(base),
      isTrue,
    );
    expect(with_(zoom: 16.6).differsFrom(base), isTrue);
    expect(with_(bearing: 5).differsFrom(base), isTrue);
    expect(with_(pitch: 10).differsFrom(base), isTrue);
  });
}
