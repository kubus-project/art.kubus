import 'package:art_kubus/widgets/common/kubus_filter_panel.dart';
import 'package:art_kubus/widgets/map/glass/kubus_map_platform_backdrop_host.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the map screen's stable-parent + keyed [AnimatedSwitcher] filter
/// panel lifecycle so we can assert the glass behaviour in isolation (the full
/// map screen is too heavy to pump here).
///
/// The default test platform is Android, where MapLibre renders as a
/// Virtual-Display texture that Flutter's [BackdropFilter] can sample, so the
/// panel uses REAL blur immediately on open (no static sheen fallback) and
/// leaves nothing behind on close. The Android real-blur path never registers a
/// platform backdrop region (that host is web/native-iOS only).
class _FilterPanelHost extends StatefulWidget {
  const _FilterPanelHost({super.key, required this.controller});

  final KubusMapBackdropHostController controller;

  @override
  State<_FilterPanelHost> createState() => _FilterPanelHostState();
}

class _FilterPanelHostState extends State<_FilterPanelHost> {
  bool open = false;

  void setOpen(bool value) => setState(() => open = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: KubusMapBackdropScope(
          controller: widget.controller,
          child: Stack(
            children: [
              // The host (extraContent equivalent) is ALWAYS mounted; only the
              // keyed AnimatedSwitcher child changes between open/closed.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: open
                    ? const KeyedSubtree(
                        key: ValueKey<String>('map_filter_panel_open'),
                        child: KubusFilterPanel(
                          title: 'Filters',
                          useMapGlassSurface: true,
                          isWebOverride: false,
                          backdropRegionId: 'map-filter-panel',
                          child: Text('Filter content'),
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey<String>('map_filter_panel_closed'),
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
    'filter panel: closed mounts stable parent, open shows real blur '
    'immediately, close leaves no ghost glass/backdrop',
    (tester) async {
      // The default test platform is Android, so the panel resolves to real
      // BackdropFilter blur over the Virtual-Display map texture.
      final controller = KubusMapBackdropHostController();
      addTearDown(controller.dispose);

      final hostKey = GlobalKey<_FilterPanelHostState>();
      await tester.pumpWidget(
        _FilterPanelHost(key: hostKey, controller: controller),
      );
      await tester.pump();

      // Closed: the stable parent (AnimatedSwitcher) is mounted, but there is
      // no panel content and no glass surface.
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.text('Filter content'), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(KubusMapGlassMaterialSheen), findsNothing);

      // Open: the panel and its real blur appear on the very first frame (no
      // extra interaction needed). The Android real-blur path never registers a
      // platform backdrop region, and never needs the static sheen fallback.
      hostKey.currentState!.setOpen(true);
      await tester.pump();
      expect(find.text('Filter content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);
      expect(find.byType(KubusMapGlassMaterialSheen), findsNothing);
      expect(find.byType(KubusMapBackdropRegionTracker), findsNothing);
      expect(controller.regionCount, 0);

      // Close: after the switch-out animation completes, the panel and its
      // glass are gone — no ghost glass/backdrop remains.
      hostKey.currentState!.setOpen(false);
      await tester.pumpAndSettle();
      expect(find.text('Filter content'), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(KubusMapGlassMaterialSheen), findsNothing);
      expect(controller.regionCount, 0);
    },
  );
}
