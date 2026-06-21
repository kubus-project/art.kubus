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

  testWidgets(
      'filter panel with maxHeight bounds height and scrolls tall content in '
      'an unbounded parent', (tester) async {
    // Reproduce the mobile top-overlay placement: a Positioned with only
    // top/left/right gives the panel an UNBOUNDED height. Without maxHeight the
    // inner SingleChildScrollView would shrink-wrap (no scroll) and overflow.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: KubusFilterPanel(
                  title: 'Filters',
                  maxHeight: 200,
                  child: Column(
                    children: [
                      for (var i = 0; i < 40; i++)
                        SizedBox(height: 30, child: Text('row $i')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // No RenderFlex overflow was thrown during layout.
    expect(tester.takeException(), isNull);

    // The panel is bounded by maxHeight (it is NOT 1200px of content tall).
    final panelHeight =
        tester.getSize(find.byType(KubusFilterPanel)).height;
    expect(panelHeight, lessThanOrEqualTo(201.0));

    // The content scrolls: the first row is visible, and after dragging up it
    // scrolls out of view.
    final scrollable = find.descendant(
      of: find.byType(KubusFilterPanel),
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);

    // The content is taller than the bound, so there is real scroll extent and
    // dragging moves the viewport.
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pump();
    expect(position.pixels, greaterThan(0));
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
