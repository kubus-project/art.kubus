import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:art_kubus/widgets/common/kubus_glass_chip.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:art_kubus/widgets/search/kubus_general_search.dart';
import 'package:art_kubus/widgets/search/kubus_search_bar.dart';
import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:art_kubus/widgets/search/kubus_search_controller.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(body: Center(child: child)),
  );
}

class _FakeSearchService extends SearchService {
  _FakeSearchService(this.results);

  final List<KubusSearchResult> results;

  @override
  Future<List<KubusSearchResult>> fetchResults({
    required SearchContextSnapshot snapshot,
    required String query,
    required KubusSearchConfig config,
  }) async {
    return results;
  }
}

/// Mirrors the on-map composition: a [KubusGeneralSearch] field plus the
/// floating [KubusSearchResultsOverlay] dropdown, both in map-glass mode.
class _MapSearchHarness extends StatelessWidget {
  const _MapSearchHarness({
    required this.controller,
    required this.themeProvider,
    required this.onResultTap,
  });

  final KubusSearchController controller;
  final ThemeProvider themeProvider;
  final ValueChanged<KubusSearchResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: KubusGeneralSearch(
                  controller: controller,
                  hintText: 'Search the map',
                  semanticsLabel: 'map_search_input',
                  // Mirror the mobile map: the screen passes
                  // kubusMapBlurEnabled() which is false over the native
                  // MapLibre platform view.
                  enableBlur: false,
                  useMapGlassSurface: true,
                ),
              ),
              KubusSearchResultsOverlay(
                controller: controller,
                minCharsHint: 'Type at least 2 characters',
                noResultsText: 'No results',
                accentColor: Colors.teal,
                useMapGlassSurface: true,
                // Mirror the field: blur is off over the native MapLibre
                // platform view, so the dropdown must take the safe-tint +
                // sheen fallback instead of a BackdropFilter in front of text.
                enableBlur: false,
                onResultTap: onResultTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('KubusSearchBar map glass mode', () {
    testWidgets(
        'fallback over the map drops BackdropFilter and adds the material sheen',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusSearchBar(
            hintText: 'Search',
            // Mirrors what the map screen passes via kubusMapBlurEnabled() when
            // sitting over the native MapLibre platform view.
            enableBlur: false,
            useMapGlassSurface: true,
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(KubusMapGlassMaterialSheen), findsOneWidget);
    });

    testWidgets('normal search bar fallback does NOT use the map sheen',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusSearchBar(
            hintText: 'Search',
            enableBlur: false,
            useMapGlassSurface: false,
          ),
        ),
      );

      expect(find.byType(KubusMapGlassMaterialSheen), findsNothing);
    });

    testWidgets('map mode keeps real blur when blur is available',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KubusSearchBar(
            hintText: 'Search',
            enableBlur: true,
            useMapGlassSurface: true,
          ),
        ),
      );

      // Provider absent => GlassSurface defaults to real blur, and the sheen is
      // only for the blur-off fallback.
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(KubusMapGlassMaterialSheen), findsNothing);
    });

    testWidgets(
        'map-glass fallback preserves hint, input, focus and change/submit '
        'callbacks', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      String? changed;
      String? submitted;

      await tester.pumpWidget(
        _wrap(
          KubusSearchBar(
            hintText: 'Find art',
            controller: controller,
            focusNode: focusNode,
            enableBlur: false,
            useMapGlassSurface: true,
            onChanged: (value) => changed = value,
            onSubmitted: (value) => submitted = value,
          ),
        ),
      );

      // Sheen fallback is active, but the text field still works fully.
      expect(find.byType(KubusMapGlassMaterialSheen), findsOneWidget);
      expect(find.text('Find art'), findsOneWidget); // hint visible

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.enterText(find.byType(TextField), 'mural');
      await tester.pump();
      expect(controller.text, 'mural');
      expect(changed, 'mural');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, 'mural');
    });
  });

  group('KubusSearchResultsOverlay map glass mode', () {
    testWidgets(
        'dropdown fallback shows the sheen and results remain tappable',
        (tester) async {
      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = KubusSearchController(
        config: const KubusSearchConfig(
          scope: KubusSearchScope.map,
          debounceDuration: Duration.zero,
        ),
        searchService: _FakeSearchService(
          const <KubusSearchResult>[
            KubusSearchResult(
              label: 'Ocean Light',
              kind: KubusSearchResultKind.artwork,
              id: 'art-1',
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      KubusSearchResult? tapped;

      await tester.pumpWidget(
        _MapSearchHarness(
          controller: controller,
          themeProvider: themeProvider,
          onResultTap: (result) => tapped = result,
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Ocean');
      await tester.pump();
      await tester.pump();

      // Dropdown is open over the map: it must read as map glass (sheen) with
      // no raw BackdropFilter required on this fallback path.
      final resultTile = find.widgetWithText(ListTile, 'Ocean Light');
      expect(resultTile, findsOneWidget);
      expect(find.byType(KubusMapGlassMaterialSheen), findsWidgets);
      expect(find.byType(BackdropFilter), findsNothing);

      // Still tappable.
      tester.widget<ListTile>(resultTile).onTap?.call();
      await tester.pumpAndSettle();
      expect(tapped?.id, 'art-1');
    });
  });

  group('KubusGlassChip map glass fallback', () {
    testWidgets('quick filter chip gets the sheen when real blur is off',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          KubusGlassChip(
            label: 'Nearby',
            icon: Icons.near_me,
            active: false,
            enableBlur: false,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(KubusMapGlassMaterialSheen), findsOneWidget);
    });

    testWidgets('quick filter chip keeps real blur when available',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          KubusGlassChip(
            label: 'Nearby',
            icon: Icons.near_me,
            active: false,
            enableBlur: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(KubusMapGlassMaterialSheen), findsNothing);
    });
  });
}
