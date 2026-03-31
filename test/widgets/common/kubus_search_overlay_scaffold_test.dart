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
  final fieldLink = LayerLink();

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
            searchFieldLink: fieldLink,
            showSuggestions: showSuggestions,
            query: showSuggestions ? 'ma' : '',
            isFetching: false,
            suggestions: const [],
            accentColor: Colors.teal,
            minCharsHint: 'Type at least 2 characters',
            noResultsText: 'No results',
            onDismissSuggestions: _noop,
            onSuggestionTap: (_) {},
            leading: const Text('Discover'),
            filterChips: const Text('Filters'),
            mapToggle: const Icon(Icons.tune),
          ),
        ],
      ),
    ),
  );
}

void _noop() {}

void main() {
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
