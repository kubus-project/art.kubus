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

  double scaffoldFieldWidth(WidgetTester tester) {
    return tester
        .widget<KubusSearchOverlayScaffold>(
          find.byType(KubusSearchOverlayScaffold),
        )
        .topOverlayFieldWidth!;
  }

  double dropdownWidth(WidgetTester tester) {
    return tester
        .widget<KubusSearchResultsOverlay>(
          find.byType(KubusSearchResultsOverlay),
        )
        .width!;
  }

  testWidgets(
    'map search expands on focus and shares one width with the dropdown',
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
        ChangeNotifierProvider<ThemeProvider>.value(
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
                    layout: KubusSearchOverlayLayout.topOverlay,
                    minCharsHint: 'Type more',
                    noResultsText: 'No results',
                    onResultTap: (_) {},
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
        ),
      );
      await tester.pumpAndSettle();

      // Idle: field is comfortable but not the full available width, and the
      // dropdown shares exactly the same width contract.
      final idleWidth = scaffoldFieldWidth(tester);
      expect(dropdownWidth(tester), idleWidth);

      // Focus the field -> it expands to the available safe width.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      final focusedWidth = scaffoldFieldWidth(tester);
      expect(focusedWidth, greaterThan(idleWidth),
          reason: 'search bar should expand when focused');

      // The dropdown stays locked to the field width (never grows to the
      // right independently).
      expect(dropdownWidth(tester), focusedWidth);
    },
  );
}
