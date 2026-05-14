import 'package:art_kubus/widgets/common/kubus_filter_panel.dart';
import 'package:art_kubus/widgets/map/glass/kubus_map_platform_backdrop_host.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filter panel default remains generic glass', (tester) async {
    final controller = KubusMapBackdropHostController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KubusMapBackdropScope(
            controller: controller,
            child: const KubusFilterPanel(
              title: 'Filters',
              child: Text('Generic content'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(KubusMapBackdropRegionTracker), findsNothing);
    expect(controller.regionCount, 0);
    expect(find.text('Generic content'), findsOneWidget);
  });

  testWidgets('filter side panel can opt into map glass backdrop region',
      (tester) async {
    final controller = KubusMapBackdropHostController();
    var buttonTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KubusMapBackdropScope(
            controller: controller,
            child: KubusFilterPanel(
              title: 'Filters',
              useMapGlassSurface: true,
              mapBlurPolicy: KubusMapBlurPolicy.forceMapChromeWhenCapable,
              backdropRegionId: 'desktop-map-filter-panel',
              isWebOverride: true,
              platformBackdropHostAvailableOverride: true,
              child: TextButton(
                onPressed: () => buttonTapped += 1,
                child: const Text('Apply'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(KubusMapBackdropRegionTracker), findsOneWidget);
    expect(controller.regionCount, 1);
    expect(controller.regions.single.id, 'desktop-map-filter-panel');

    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(buttonTapped, 1);
  });

  testWidgets('filter panel map glass uses fallback when host unavailable',
      (tester) async {
    final controller = KubusMapBackdropHostController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KubusMapBackdropScope(
            controller: controller,
            child: const KubusFilterPanel(
              title: 'Filters',
              useMapGlassSurface: true,
              mapBlurPolicy: KubusMapBlurPolicy.forceMapChromeWhenCapable,
              isWebOverride: true,
              platformBackdropHostAvailableOverride: false,
              backdropRegionId: 'desktop-map-filter-panel',
              child: Text('Fallback content'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(KubusMapBackdropRegionTracker), findsNothing);
    expect(controller.regionCount, 0);
    expect(find.text('Fallback content'), findsOneWidget);
  });
}
