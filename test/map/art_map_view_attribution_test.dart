import 'dart:io';
import 'dart:math' as math;

import 'package:art_kubus/features/map/shared/map_screen_constants.dart';
import 'package:art_kubus/widgets/art_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

void main() {
  testWidgets('ArtMapView keeps attribution offset configuration wired',
      (tester) async {
    final margins = math.Point<double>(12, 84);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArtMapView(
            initialCenter: const ll.LatLng(46.056946, 14.505751),
            initialZoom: 12,
            minZoom: 3,
            maxZoom: 24,
            isDarkMode: false,
            styleAsset: 'assets/map_styles/kubus_light.json',
            attributionButtonPosition: ml.AttributionButtonPosition.bottomLeft,
            attributionButtonMargins: margins,
            onMapCreated: (_) {},
          ),
        ),
      ),
    );

    final mapView = tester.widget<ArtMapView>(find.byType(ArtMapView));
    expect(
      mapView.attributionButtonPosition,
      ml.AttributionButtonPosition.bottomLeft,
    );
    expect(mapView.attributionButtonMargins, margins);
  });

  test('mobile and desktop map screens pass attribution offsets to ArtMapView',
      () {
    expect(MapScreenConstants.desktopAttributionBottomPx, 12.0);

    final mobileSource = File('lib/screens/map_screen.dart').readAsStringSync();
    final desktopSource =
        File('lib/screens/desktop/desktop_map_screen.dart').readAsStringSync();

    expect(
      mobileSource,
      matches(
        RegExp(
          r'attributionButtonMargins:\s*math\.Point<double>\(\s*'
          r'12\.0,\s*attributionBottomMargin,\s*\)',
        ),
      ),
    );
    expect(
      desktopSource,
      matches(
        RegExp(
          r'attributionButtonMargins:\s*math\.Point<double>\(\s*'
          r'24\.0,\s*KubusSpacing\.xl\.toDouble\(\),\s*\)',
        ),
      ),
    );
  });

  test(
      'desktop suppresses native MapLibre attribution while keeping the '
      'custom button', () {
    final indexHtml = File('web/index.html').readAsStringSync();
    // The native MapLibre attribution must be hidden on desktop so only the
    // custom attribution button is visible.
    expect(
      indexHtml,
      matches(
        RegExp(
          r'body\.kubus-desktop-map \.maplibregl-ctrl-attrib,\s*'
          r'body\.kubus-desktop-map \.maplibregl-ctrl-attrib-button \{\s*'
          r'display:\s*none\s*!important;',
        ),
      ),
    );

    final desktopSource =
        File('lib/screens/desktop/desktop_map_screen.dart').readAsStringSync();
    // The custom attribution button (info glass button) stays on desktop.
    expect(desktopSource, contains('_buildDesktopAttributionButton'));

    // Mobile keeps the native attribution accessible (not display:none).
    expect(
      indexHtml,
      isNot(contains('body.kubus-mobile-map .maplibregl-ctrl-attrib {\n'
          '      display: none')),
    );
  });
}
