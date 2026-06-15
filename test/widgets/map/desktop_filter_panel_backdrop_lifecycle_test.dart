import 'package:art_kubus/widgets/common/kubus_filter_panel.dart';
import 'package:art_kubus/widgets/map/glass/kubus_map_platform_backdrop_host.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the desktop map screen's left-panel filter lifecycle in isolation
/// (the full DesktopMapScreen is far too heavy to pump here).
///
/// The desktop filter panel shares a single sliding slot with the detail
/// panels. While it rests offscreen (filters closed, nothing selected) it must
/// NOT register a live platform backdrop region — otherwise the region is
/// measured at the stale offscreen geometry and the blur only "catches up"
/// after an unrelated interaction. So the closed state builds a region-disabled
/// panel and the open state builds the real region-tracked panel under a stable
/// key.
///
/// This host forces the web platform-backdrop-host strategy (isWebOverride +
/// platformBackdropHostAvailableOverride) so the region tracker actually builds
/// and the controller's region count is observable.
class _DesktopFilterSlotHost extends StatefulWidget {
  const _DesktopFilterSlotHost({super.key, required this.controller});

  final KubusMapBackdropHostController controller;

  @override
  State<_DesktopFilterSlotHost> createState() => _DesktopFilterSlotHostState();
}

class _DesktopFilterSlotHostState extends State<_DesktopFilterSlotHost> {
  bool open = false;

  void setOpen(bool value) => setState(() => open = value);

  Widget _filterPanel({required bool enableBackdropRegion}) {
    return KubusFilterPanel(
      title: 'Filters',
      useMapGlassSurface: true,
      mapBlurPolicy: KubusMapBlurPolicy.forceMapChromeWhenCapable,
      overMapPlatformView: true,
      enablePlatformBackdropRegion: enableBackdropRegion,
      backdropRegionId: 'desktop-map-filter-panel',
      isWebOverride: true,
      platformBackdropHostAvailableOverride: true,
      child: const Text('Filter content'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: KubusMapBackdropScope(
          controller: widget.controller,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 380,
                height: 480,
                child: KeyedSubtree(
                  key: ValueKey<String>(
                    open
                        ? 'desktop_filter_panel_open'
                        : 'desktop_filter_panel_closed',
                  ),
                  child: _filterPanel(enableBackdropRegion: open),
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
  testWidgets(
    'desktop filter slot: closed registers no backdrop region, open registers '
    'one, close clears it',
    (tester) async {
      final controller = KubusMapBackdropHostController();
      addTearDown(controller.dispose);

      final hostKey = GlobalKey<_DesktopFilterSlotHostState>();
      await tester.pumpWidget(
        _DesktopFilterSlotHost(key: hostKey, controller: controller),
      );
      await tester.pumpAndSettle();

      // Closed: the region-disabled panel never builds a tracker and never
      // registers a region.
      expect(
        find.byKey(const ValueKey<String>('desktop_filter_panel_closed')),
        findsOneWidget,
      );
      expect(find.byType(KubusMapBackdropRegionTracker), findsNothing);
      expect(controller.regionCount, 0);

      // Open: the real panel builds the region tracker and registers exactly one
      // region (no interaction required).
      hostKey.currentState!.setOpen(true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('desktop_filter_panel_open')),
        findsOneWidget,
      );
      expect(find.byType(KubusMapBackdropRegionTracker), findsOneWidget);
      expect(controller.regionCount, 1);

      // Close: the tracked panel is torn down and its region removed — no stale
      // backdrop region remains.
      hostKey.currentState!.setOpen(false);
      await tester.pumpAndSettle();
      expect(find.byType(KubusMapBackdropRegionTracker), findsNothing);
      expect(controller.regionCount, 0);
    },
  );
}
