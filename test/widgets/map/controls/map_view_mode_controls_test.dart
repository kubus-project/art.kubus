import 'package:art_kubus/widgets/map/controls/map_view_mode_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders and invokes the isometric control', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapViewModeControls(
            density: MapViewModeControlsDensity.mobileRail,
            showIsometricViewToggle: true,
            isometricViewActive: false,
            onToggleIsometricView: () => taps += 1,
            isometricViewIcon: Icons.filter_tilt_shift,
            isometricViewTooltip: 'Isometric',
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.filter_tilt_shift));
    expect(taps, 1);
  });
}
