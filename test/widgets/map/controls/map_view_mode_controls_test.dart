import 'package:art_kubus/widgets/map/controls/map_view_mode_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MapViewModeControls invokes mobile toggle callbacks', (tester) async {
    var travelTapped = 0;
    var isometricTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapViewModeControls(
            density: MapViewModeControlsDensity.mobileRail,
            showTravelModeToggle: true,
            travelModeActive: false,
            onToggleTravelMode: () => travelTapped += 1,
            showIsometricViewToggle: true,
            isometricViewActive: false,
            onToggleIsometricView: () => isometricTapped += 1,
            travelModeIcon: Icons.travel_explore,
            isometricViewIcon: Icons.filter_tilt_shift,
            travelModeTooltip: 'Travel',
            isometricViewTooltip: 'Isometric',
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.travel_explore));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.filter_tilt_shift));
    await tester.pump();

    expect(travelTapped, 1);
    expect(isometricTapped, 1);
  });

  testWidgets('MapViewModeControls renders desktop toggles with separators',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapViewModeControls(
            density: MapViewModeControlsDensity.desktopToolbar,
            showTravelModeToggle: true,
            travelModeActive: true,
            onToggleTravelMode: () {},
            showIsometricViewToggle: true,
            isometricViewActive: false,
            onToggleIsometricView: () {},
            travelModeIcon: Icons.travel_explore,
            isometricViewIcon: Icons.filter_tilt_shift,
            travelModeTooltip: 'Travel',
            isometricViewTooltip: 'Isometric',
            appendTrailingSeparator: true,
            separatorBuilder: (_) => const SizedBox(
              key: ValueKey<String>('separator'),
              width: 4,
              height: 4,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.travel_explore), findsOneWidget);
    expect(find.byIcon(Icons.filter_tilt_shift), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('separator')), findsNWidgets(2));
  });
}
