import 'package:art_kubus/features/map/shared/map_search_filter_assembly.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/common/kubus_search_overlay_scaffold.dart';
import 'package:art_kubus/widgets/search/kubus_general_search.dart';
import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:art_kubus/widgets/search/kubus_search_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  double topOverlayFieldWidth(WidgetTester tester) {
    return tester
        .widget<KubusSearchOverlayScaffold>(
          find.byType(KubusSearchOverlayScaffold),
        )
        .topOverlayFieldWidth!;
  }

  double sidePanelFieldWidth(WidgetTester tester) {
    return tester
        .widget<KubusSearchOverlayScaffold>(
          find.byType(KubusSearchOverlayScaffold),
        )
        .sidePanelFieldWidth!;
  }

  double dropdownWidth(WidgetTester tester) {
    return tester
        .widget<KubusSearchResultsOverlay>(
          find.byType(KubusSearchResultsOverlay),
        )
        .width!;
  }

  Widget wrap({
    required KubusSearchController controller,
    required ThemeProvider themeProvider,
    required KubusSearchOverlayLayout layout,
  }) {
    return ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Stack(
            children: [
              KubusMapSearchOverlayAssembly(
                controller: controller,
                layout: layout,
                minCharsHint: 'Type more',
                noResultsText: 'No results',
                onResultTap: (_) {},
                leading: const Text('Discover'),
                filterChips: const Text('Filters'),
                mapToggle: const Icon(Icons.tune),
                searchField: KubusGeneralSearch(
                  controller: controller,
                  hintText: 'Search',
                  semanticsLabel: 'map_search_input',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets(
    'mobile (top overlay) search is full width and does not change on focus',
    (tester) async {
      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = KubusSearchController(
        config: const KubusSearchConfig(
          scope: KubusSearchScope.map,
          debounceDuration: Duration.zero,
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          controller: controller,
          themeProvider: themeProvider,
          layout: KubusSearchOverlayLayout.topOverlay,
        ),
      );
      await tester.pumpAndSettle();

      // Full width before focus, and the dropdown shares exactly the same width.
      final idleWidth = topOverlayFieldWidth(tester);
      expect(dropdownWidth(tester), idleWidth);

      // Focusing the field must NOT widen it on mobile.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(topOverlayFieldWidth(tester), idleWidth,
          reason: 'mobile search must stay full width on focus');
      expect(dropdownWidth(tester), idleWidth);
    },
  );

  testWidgets(
    'desktop (side panel) search expands on focus and shares the dropdown width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = KubusSearchController(
        config: const KubusSearchConfig(
          scope: KubusSearchScope.map,
          debounceDuration: Duration.zero,
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          controller: controller,
          themeProvider: themeProvider,
          layout: KubusSearchOverlayLayout.sidePanel,
        ),
      );
      await tester.pumpAndSettle();

      // Idle: comfortable width; the dropdown shares exactly the same width.
      final idleWidth = sidePanelFieldWidth(tester);
      expect(dropdownWidth(tester), idleWidth);

      // Focus -> the field expands toward the right.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      final focusedWidth = sidePanelFieldWidth(tester);
      expect(focusedWidth, greaterThan(idleWidth),
          reason: 'desktop side-panel search should expand when focused');

      // The dropdown stays locked to the (expanded) field width.
      expect(dropdownWidth(tester), focusedWidth);
    },
  );
}
