import 'package:art_kubus/widgets/common/kubus_search_overlay_scaffold.dart';
import 'package:art_kubus/widgets/glass/glass_surface.dart';
import 'package:art_kubus/widgets/map_overlay_blocker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildSearchOverlay(
  KubusSearchSidePanelSurfaceMode mode, {
  bool animated = false,
  double rightInset = 0,
  bool showSuggestions = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          KubusSearchOverlayScaffold(
            layout: KubusSearchOverlayLayout.sidePanel,
            sidePanelSurfaceMode: mode,
            sidePanelAnimated: animated,
            rightInset: rightInset,
            searchField: const SizedBox(
              key: ValueKey<String>('search_field'),
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black12),
              ),
            ),
            searchDropdown: showSuggestions
                ? const Positioned.fill(
                    child: MapOverlayBlocker(
                      child: SizedBox.shrink(),
                    ),
                  )
                : null,
            leading: const Text('Discover'),
            filterChips: const Text('Filters'),
            mapToggle: const Icon(Icons.tune),
          ),
        ],
      ),
    ),
  );
}

Widget _buildHeaderToolbar({
  required double fieldWidth,
  required bool expanded,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          KubusSearchOverlayScaffold(
            layout: KubusSearchOverlayLayout.sidePanel,
            sidePanelSurfaceMode: KubusSearchSidePanelSurfaceMode.hostless,
            // Setting the resolved field width selects the map-assembly header
            // path (single-line toolbar + chips on a deliberate row below).
            sidePanelFieldWidth: fieldWidth,
            sidePanelSearchExpanded: expanded,
            searchField: const SizedBox(
              key: ValueKey<String>('search_field'),
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black12),
              ),
            ),
            leading: const Text('Discover', key: ValueKey<String>('leading')),
            filterChips: const Text('Filters'),
            mapToggle: const Icon(Icons.tune),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
      'desktop header keeps logo/title and search field aligned on one row',
      (tester) async {
    await tester.pumpWidget(
      _buildHeaderToolbar(fieldWidth: 320, expanded: false),
    );
    await tester.pump();

    final leadingCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('leading')),
    );
    final fieldCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('search_field')),
    );

    // The title and the search field must share the same baseline (single
    // toolbar line) instead of the field dropping onto a second row.
    expect((leadingCenter.dy - fieldCenter.dy).abs(), lessThan(1.0));
    // Field sits to the right of the title.
    expect(fieldCenter.dx, greaterThan(leadingCenter.dx));
    // Quick filters render (on the deliberate second row) while idle.
    expect(find.text('Filters'), findsOneWidget);
  });

  testWidgets('desktop header collapses quick filters when search is expanded',
      (tester) async {
    await tester.pumpWidget(
      _buildHeaderToolbar(fieldWidth: 620, expanded: true),
    );
    await tester.pump();

    // When focused/expanded the chips collapse so the field can grow right.
    expect(find.text('Filters'), findsNothing);
    expect(find.byKey(const ValueKey<String>('search_field')), findsOneWidget);
  });

  testWidgets('side panel with glassHost renders outer GlassSurface',
      (tester) async {
    await tester.pumpWidget(
      _buildSearchOverlay(KubusSearchSidePanelSurfaceMode.glassHost),
    );

    expect(find.byKey(const ValueKey<String>('search_field')), findsOneWidget);
    expect(find.byType(GlassSurface), findsOneWidget);
    expect(find.byType(MapOverlayBlocker), findsOneWidget);
  });

  testWidgets('side panel hostless mode removes outer GlassSurface',
      (tester) async {
    await tester.pumpWidget(
      _buildSearchOverlay(
        KubusSearchSidePanelSurfaceMode.hostless,
        animated: true,
        rightInset: 360,
      ),
    );

    expect(find.byKey(const ValueKey<String>('search_field')), findsOneWidget);
    expect(find.byType(GlassSurface), findsNothing);
    expect(find.byType(MapOverlayBlocker), findsOneWidget);

    final animatedPositioned = tester.widget<AnimatedPositioned>(
      find.byType(AnimatedPositioned),
    );
    expect(animatedPositioned.right, 360);
  });

  testWidgets(
    'side panel with suggestions keeps both panel and suggestions blocked',
    (tester) async {
      await tester.pumpWidget(
        _buildSearchOverlay(
          KubusSearchSidePanelSurfaceMode.hostless,
          showSuggestions: true,
        ),
      );

      expect(find.byType(MapOverlayBlocker), findsNWidgets(2));
    },
  );
}
