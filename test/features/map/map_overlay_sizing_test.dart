import 'package:art_kubus/features/map/shared/map_overlay_sizing.dart';
import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtMarker _markerAt(double lat, double lng) {
  return ArtMarker(
    id: 'marker-1',
    name: 'Marker',
    description: '',
    position: LatLng(lat, lng),
    type: ArtMarkerType.artwork,
    createdAt: DateTime(2024, 1, 1),
    createdBy: 'tester',
  );
}

void main() {
  group('MapOverlaySizing.resolveMarkerOverlayCardLayout', () {
    test('keeps mobile and desktop in the same card width family', () {
      const media = MediaQueryData(size: Size(390, 780));
      final mobile = MapOverlaySizing.resolveMarkerOverlayCardLayout(
        constraints: const BoxConstraints(maxWidth: 390, maxHeight: 780),
        media: media,
        isDesktop: false,
      );
      final desktop = MapOverlaySizing.resolveMarkerOverlayCardLayout(
        constraints: const BoxConstraints(maxWidth: 1280, maxHeight: 800),
        media: media,
        isDesktop: true,
      );

      expect(mobile.width, inInclusiveRange(272, 336));
      expect(desktop.width, inInclusiveRange(272, 336));
      expect(mobile.maxHeight, greaterThanOrEqualTo(280));
      expect(desktop.maxHeight, greaterThanOrEqualTo(280));
      expect(mobile.compact, isTrue);
      expect(desktop.compact, isFalse);
    });
  });

  group('KubusMarkerOverlayHelpers.resolveDistanceText', () {
    test('formats meters and kilometers consistently', () {
      const distance = Distance();
      final user = const LatLng(46.0569, 14.5058);

      expect(
        KubusMarkerOverlayHelpers.resolveDistanceText(
          userLocation: user,
          marker: _markerAt(46.0578, 14.5058),
          distance: distance,
        ),
        endsWith('m'),
      );
      expect(
        KubusMarkerOverlayHelpers.resolveDistanceText(
          userLocation: user,
          marker: _markerAt(46.0700, 14.5058),
          distance: distance,
        ),
        endsWith('km'),
      );
      expect(
        KubusMarkerOverlayHelpers.resolveDistanceText(
          userLocation: null,
          marker: _markerAt(46.0700, 14.5058),
          distance: distance,
        ),
        isNull,
      );
    });
  });
}
