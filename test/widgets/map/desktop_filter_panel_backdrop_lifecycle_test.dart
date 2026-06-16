import 'package:art_kubus/widgets/common/kubus_filter_panel.dart';
import 'package:art_kubus/widgets/map/glass/kubus_map_platform_backdrop_host.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the desktop map screen's left-panel filter lifecycle in isolation
/// (the full DesktopMapScreen is far too heavy to pump here).
///
/// The desktop filter panel shares a single sliding slot with the detail
/// panels. While it rests closed/offscreen it must NOT register a live platform
/// backdrop region — otherwise the region is measured at the stale offscreen
/// geometry and the blur only "catches up" after an unrelated interaction. So
/// the closed state is an empty placeholder (no live KubusFilterPanel, hence no
/// region tracker) and the open state builds the real region-tracked panel
/// under a stable key inside a keyed AnimatedSwitcher.
///
/// This host forces the web platform-backdrop-host strategy (isWebOverride +
/// platformBackdropHostAvailableOverride) so the region tracker actually builds
/// and the controller's region count is observable.
class _DesktopFilterSlotHost extends StatelessWidget {
  const _DesktopFilterSlotHost({
    required this.controller,
    required this.open,
  });

  final KubusMapBackdropHostController controller;
  final bool open;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: KubusMapBackdropScope(
          controller: controller,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 380,
                height: 480,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: open
                      ? const KeyedSubtree(
                          key: ValueKey<String>('desktop_filter_panel_open'),
                          child: KubusFilterPanel(
                            title: 'Filters',
                            useMapGlassSurface: true,
                            mapBlurPolicy:
                                KubusMapBlurPolicy.forceMapChromeWhenCapable,
                            overMapPlatformView: true,
                            enablePlatformBackdropRegion: true,
                            backdropRegionId: 'desktop-map-filter-panel',
                            isWebOverride: true,
                            platformBackdropHostAvailableOverride: true,
                            child: Text('Filter content'),
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey<String>('desktop_filter_panel_closed'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('closed filter slot registers no live backdrop region',
      (tester) async {
    final controller = KubusMapBackdropHostController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _DesktopFilterSlotHost(controller: controller, open: false),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('desktop_filter_panel_closed')),
      findsOneWidget,
    );
    expect(find.text('Filter content'), findsNothing);
    expect(find.byType(KubusMapBackdropRegionTracker), findsNothing);
    expect(controller.regionCount, 0);
  });

  testWidgets('open filter slot registers exactly one backdrop region',
      (tester) async {
    final controller = KubusMapBackdropHostController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _DesktopFilterSlotHost(controller: controller, open: true),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('desktop_filter_panel_open')),
      findsOneWidget,
    );
    expect(find.text('Filter content'), findsOneWidget);
    expect(find.byType(KubusMapBackdropRegionTracker), findsOneWidget);
    expect(controller.regionCount, 1);
    expect(controller.regions.single.id, 'desktop-map-filter-panel');
  });

  testWidgets('tearing down the open filter panel clears its region',
      (tester) async {
    final controller = KubusMapBackdropHostController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _DesktopFilterSlotHost(controller: controller, open: true),
    );
    await tester.pump();
    expect(controller.regionCount, 1);

    // Replace the whole scope subtree (closing the panel ultimately tears down
    // its region tracker). The tracker's dispose removes its region, so no
    // stale backdrop region is left behind.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    await tester.pump();

    expect(find.byType(KubusMapBackdropRegionTracker), findsNothing);
    expect(controller.regionCount, 0);
  });
}
