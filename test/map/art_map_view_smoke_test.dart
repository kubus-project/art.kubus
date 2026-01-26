import 'package:art_kubus/widgets/art_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as ll;

void main() {
  testWidgets('ArtMapView mounts in widget tests', (tester) async {
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
            onMapCreated: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('art_map_view_test_placeholder')), findsOneWidget);
  });
}

