import 'dart:ui';

import 'package:art_kubus/features/map/capabilities/kubus_map_capabilities.dart';
import 'package:art_kubus/features/map/shared/map_spatial_framing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('framing levels', () {
    test('world to artwork is monotonic over zoom', () {
      const expected = <(double, MapFramingLevel)>[
        (0.0, MapFramingLevel.world),
        (2.55, MapFramingLevel.world),
        (3.5, MapFramingLevel.region),
        (4.0, MapFramingLevel.region),
        (5.5, MapFramingLevel.country),
        (7.0, MapFramingLevel.country),
        (8.5, MapFramingLevel.city),
        (12.0, MapFramingLevel.city),
        (12.5, MapFramingLevel.neighbourhood),
        (14.9, MapFramingLevel.neighbourhood),
        (15.0, MapFramingLevel.street),
        (16.9, MapFramingLevel.street),
        (17.0, MapFramingLevel.artwork),
        (21.0, MapFramingLevel.artwork),
      ];
      for (final (zoom, level) in expected) {
        expect(MapSpatialFraming.levelForZoom(zoom), level, reason: 'z=$zoom');
      }
    });

    test('the locale openings land where the product says they do', () {
      // EN: wide Europe (z4) is a region; SL: Slovenia (z7) is a country.
      expect(MapSpatialFraming.levelForZoom(4.0), MapFramingLevel.region);
      expect(MapSpatialFraming.levelForZoom(7.0), MapFramingLevel.country);
    });

    test('a non-finite zoom is the world, never a crash', () {
      expect(MapSpatialFraming.levelForZoom(double.nan), MapFramingLevel.world);
    });
  });

  group('globe minimum zoom', () {
    test('keeps the visible globe disc filling the shorter side', () {
      for (final size in const <Size>[
        Size(320, 568),
        Size(390, 844),
        Size(768, 1024),
        Size(1220, 900),
        Size(1440, 900),
        Size(1920, 1080),
      ]) {
        final z = MapSpatialFraming.globeMinZoomFor(size);
        final disc = MapSpatialFraming.globeDiscDiameter(z, size);
        final wanted = size.shortestSide * MapSpatialFraming.globeFillFraction;
        if (z > 1.0 && z < 3.2) {
          expect(disc, closeTo(wanted, wanted * 0.01),
              reason: '$size z=$z disc=$disc wanted=$wanted');
        } else {
          // Clamped: a view that wants less than the floor is larger than
          // wanted, one that wants more than the ceiling is not allowed.
          expect(z, inInclusiveRange(1.0, 3.2));
        }
      }
    });

    test('matches the measured Chromium render at 1440x900', () {
      // Equator zoom 2.35 renders a visible disc of about 653 px on a 900 px
      // tall view (measured in the Wave 5B browser QA).
      expect(
        MapSpatialFraming.globeDiscDiameter(2.35, const Size(1440, 900)),
        closeTo(653, 8),
      );
    });

    test('a bigger view needs a higher floor than a phone', () {
      expect(
        MapSpatialFraming.globeMinZoomFor(const Size(1920, 1080)),
        greaterThan(MapSpatialFraming.globeMinZoomFor(const Size(390, 844))),
      );
    });

    test('degenerate sizes get the floor', () {
      expect(MapSpatialFraming.globeMinZoomFor(Size.zero), 1.0);
      expect(
        MapSpatialFraming.globeMinZoomFor(const Size(double.nan, 200)),
        1.0,
      );
    });

    test('the flat map keeps its own minimum', () {
      expect(
        MapSpatialFraming.minZoomFor(
          globe: false,
          viewport: const Size(1440, 900),
        ),
        MapSpatialFraming.flatMinZoom,
      );
      expect(
        MapSpatialFraming.minZoomFor(
          globe: true,
          viewport: const Size(1440, 900),
        ),
        MapSpatialFraming.globeMinZoomFor(const Size(1440, 900)),
      );
    });
  });

  group('capability matrix', () {
    test('only the web renderer with the flag on draws a globe', () {
      expect(
        KubusMapCapabilities.resolve(isWeb: true, globeEnabled: true),
        KubusMapCapabilities.globe,
      );
      expect(
        KubusMapCapabilities.resolve(isWeb: true, globeEnabled: false),
        KubusMapCapabilities.flat,
      );
      // Android (MapLibre Native 13.3.0) and iOS render flat Mercator.
      expect(
        KubusMapCapabilities.resolve(isWeb: false, globeEnabled: true),
        KubusMapCapabilities.flat,
      );
      expect(
        KubusMapCapabilities.resolve(isWeb: false, globeEnabled: false),
        KubusMapCapabilities.flat,
      );
    });

    test('the test override is restorable', () {
      addTearDown(() => KubusMapCapabilities.debugOverride(null));
      KubusMapCapabilities.debugOverride(KubusMapCapabilities.globe);
      expect(KubusMapCapabilities.current.supportsGlobe, isTrue);
      KubusMapCapabilities.debugOverride(null);
      // Host test runs are not web.
      expect(KubusMapCapabilities.current.supportsGlobe, isFalse);
    });
  });
}
