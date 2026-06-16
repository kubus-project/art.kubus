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

Widget _buildHeaderToolbar() {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          KubusSearchOverlayScaffold(
            layout: KubusSearchOverlayLayout.sidePanel,
            sidePanelSurfaceMode: KubusSearchSidePanelSurfaceMode.hostless,
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
      'desktop header keeps logo/title, search field and quick filters on one row',
      (tester) async {
    await tester.pumpWidget(_buildHeaderToolbar());
    await tester.pump();

    final leadingCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('leading')),
    );
    final fieldCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('search_field')),
    );
    final chipsCenter = tester.getCenter(find.text('Filters'));

    // Title, search field and quick filters all share one horizontal line
    // (single control area) instead of the field or chips dropping to a second
    // row.
    expect((leadingCenter.dy - fieldCenter.dy).abs(), lessThan(1.0));
    expect((fieldCenter.dy - chipsCenter.dy).abs(), lessThan(8.0));
    // Left-to-right: title, then field, then quick filters.
    expect(fieldCenter.dx, greaterThan(leadingCenter.dx));
    expect(chipsCenter.dx, greaterThan(fieldCenter.dx));
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
