import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:art_kubus/widgets/common/kubus_glass_icon_button.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:art_kubus/widgets/search/kubus_general_search.dart';
import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:art_kubus/widgets/search/kubus_search_controller.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Slice B visual contract, asserted at widget level rather than by pixels:
/// the search field has one boundary, its inline controls are flat, the result
/// list is a solid surface, and each result kind reads correctly.
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

Widget _harness({
  required KubusSearchController controller,
  required ThemeProvider themeProvider,
  required ValueChanged<KubusSearchResult> onResultTap,
  bool mapGlass = true,
  Widget Function(BuildContext, String)? trailingBuilder,
  Brightness brightness = Brightness.light,
}) {
  return ChangeNotifierProvider<ThemeProvider>.value(
    value: themeProvider,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        // The overlay is positioned to fill its Stack, so the Stack must be the
        // screen, as it is in the app, not just as tall as the field.
        body: Stack(
          fit: StackFit.expand,
          children: [
            Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: KubusGeneralSearch(
                    controller: controller,
                    hintText: 'Search',
                    semanticsLabel: 'search_input',
                    enableBlur: false,
                    useMapGlassSurface: mapGlass,
                    trailingBuilder: trailingBuilder,
                  ),
                )),
            KubusSearchResultsOverlay(
              controller: controller,
              minCharsHint: 'Type at least 2 characters',
              noResultsText: 'No results',
              useMapGlassSurface: mapGlass,
              onResultTap: onResultTap,
            ),
          ],
        ),
      ),
    ),
  );
}

KubusSearchController _controller(List<KubusSearchResult> results) =>
    KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.map,
        debounceDuration: Duration.zero,
      ),
      searchService: _FakeSearchService(results),
    );

Future<void> _type(WidgetTester tester, String text) async {
  await tester.tap(find.byType(TextField));
  await tester.pump();
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.pump();
  // The shrink-wrapped list lays its rows out over a few frames.
  await tester.pumpAndSettle();
}

/// Every Border drawn anywhere inside [root] by a DecoratedBox/Container,
/// whether it is laid out around the child or painted over it.
Iterable<Border> _boxBorders(WidgetTester tester, Finder root) {
  return find
      .descendant(of: root, matching: find.byType(DecoratedBox))
      .evaluate()
      .map((e) => e.widget as DecoratedBox)
      .map((d) => d.decoration)
      .whereType<BoxDecoration>()
      .map((d) => d.border)
      .whereType<Border>();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('one field boundary', () {
    testWidgets('the map field draws a single border and no sheen rim',
        (tester) async {
      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = _controller(const <KubusSearchResult>[]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_harness(
        controller: controller,
        themeProvider: themeProvider,
        onResultTap: (_) {},
      ));

      final field = find.byType(KubusGeneralSearch);
      final bordered = _boxBorders(tester, field)
          .where((b) => b.top.style == BorderStyle.solid && b.top.width > 0);
      // Exactly one bordered box inside the field: the field boundary itself.
      expect(bordered, hasLength(1));

      final sheens = tester
          .widgetList<KubusMapGlassMaterialSheen>(
            find.descendant(
              of: field,
              matching: find.byType(KubusMapGlassMaterialSheen),
            ),
          )
          .toList();
      expect(sheens, isNotEmpty);
      expect(sheens.every((s) => !s.showRim), isTrue);
    });

    testWidgets('focusing the field does not move or resize it',
        (tester) async {
      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = _controller(const <KubusSearchResult>[]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_harness(
        controller: controller,
        themeProvider: themeProvider,
        onResultTap: (_) {},
      ));

      final before = tester.getRect(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(TextField)), before);
    });

    testWidgets('an embedded icon button has no border and no shadow',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: KubusGlassIconButton(
              icon: Icons.close,
              tooltip: 'Clear',
              embedded: true,
              onPressed: () => taps += 1,
            ),
          ),
        ),
      ));

      final button = find.byType(KubusGlassIconButton);
      expect(_boxBorders(tester, button), isEmpty);
      final shadows = find
          .descendant(of: button, matching: find.byType(DecoratedBox))
          .evaluate()
          .map((e) => (e.widget as DecoratedBox).decoration)
          .whereType<BoxDecoration>()
          .expand((d) => d.boxShadow ?? const <BoxShadow>[]);
      expect(shadows, isEmpty);

      // The hit area is unchanged: still the full 44 px target.
      expect(tester.getSize(button), const Size(44, 44));
      await tester.tap(button);
      expect(taps, 1);
    });

    testWidgets('clear and filter inside the field are flat controls',
        (tester) async {
      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = _controller(const <KubusSearchResult>[]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_harness(
        controller: controller,
        themeProvider: themeProvider,
        onResultTap: (_) {},
        trailingBuilder: (context, query) => KubusGlassIconButton(
          icon: query.isEmpty ? Icons.filter_alt : Icons.close,
          tooltip: query.isEmpty ? 'Filters' : 'Clear',
          embedded: true,
          onPressed: () {},
        ),
      ));

      // Rest: the filter control is flat.
      expect(
        _boxBorders(tester, find.byType(KubusGlassIconButton)),
        isEmpty,
      );

      // Typed: the clear control replaces it, still flat.
      await _type(tester, 'fo');
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(
        _boxBorders(tester, find.byType(KubusGlassIconButton)),
        isEmpty,
      );
    });
  });

  group('result dropdown', () {
    testWidgets('is a solid surface over the map, with no blur and no sheen',
        (tester) async {
      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = _controller(const <KubusSearchResult>[
        KubusSearchResult(
          label: 'Ocean Light',
          kind: KubusSearchResultKind.artwork,
          id: 'art-1',
        ),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_harness(
        controller: controller,
        themeProvider: themeProvider,
        onResultTap: (_) {},
      ));
      await _type(tester, 'Oc');

      final overlay = find.byType(KubusSearchResultsOverlay);
      expect(find.widgetWithText(ListTile, 'Ocean Light'), findsOneWidget);
      expect(
        find.descendant(of: overlay, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: overlay,
          matching: find.byType(KubusMapGlassMaterialSheen),
        ),
        findsNothing,
      );

      final surface = tester.widget<Material>(
        find
            .descendant(of: overlay, matching: find.byType(Material))
            .evaluate()
            .map((e) => e.widget as Material)
            .where((m) => m.shape is RoundedRectangleBorder)
            .map((m) => find.byWidget(m))
            .first,
      );
      expect(surface.color!.a, 1.0, reason: 'result text sits on opaque paper');
    });

    testWidgets('no results shows one quiet line and no stray controls',
        (tester) async {
      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = _controller(const <KubusSearchResult>[]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_harness(
        controller: controller,
        themeProvider: themeProvider,
        onResultTap: (_) {},
      ));
      await _type(tester, 'zzzz');

      final overlay = find.byType(KubusSearchResultsOverlay);
      expect(
        find.descendant(of: overlay, matching: find.text('No results')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: overlay, matching: find.byType(IconButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: overlay, matching: find.byIcon(Icons.close)),
        findsNothing,
      );
    });
  });

  group('result rows by kind', () {
    Future<void> expectRows(
      WidgetTester tester,
      List<KubusSearchResult> results,
      List<String> texts,
    ) async {
      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = _controller(results);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_harness(
        controller: controller,
        themeProvider: themeProvider,
        onResultTap: (_) {},
      ));
      await _type(tester, 'fo');

      for (final text in texts) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    }

    testWidgets('an artwork names its recorded artist, or says unknown',
        (tester) async {
      await expectRows(
        tester,
        const <KubusSearchResult>[
          KubusSearchResult(
            label: 'Robba Fountain',
            kind: KubusSearchResultKind.artwork,
            id: 'a1',
            detail: 'Francesco Robba',
            data: <String, dynamic>{'imageUrl': '/uploads/robba.jpg'},
          ),
          KubusSearchResult(
            label: 'Cours Julliene',
            kind: KubusSearchResultKind.artwork,
            id: 'a2',
          ),
        ],
        <String>['ARTWORKS', 'Francesco Robba', 'Unknown artist'],
      );
    });

    testWidgets('a collection names its owner and its size', (tester) async {
      await expectRows(
        tester,
        const <KubusSearchResult>[
          KubusSearchResult(
            label: 'Ljubljana fountains',
            kind: KubusSearchResultKind.collection,
            id: 'c1',
            detail: 'City curator',
            data: <String, dynamic>{'artworkCount': 4},
          ),
        ],
        <String>['COLLECTIONS', 'City curator · 4 artworks'],
      );
    });

    testWidgets('a profile and an institution render under their own groups',
        (tester) async {
      await expectRows(
        tester,
        const <KubusSearchResult>[
          KubusSearchResult(
            label: 'Rok',
            kind: KubusSearchResultKind.profile,
            id: 'wallet-1',
          ),
          KubusSearchResult(
            label: 'Moderna galerija',
            kind: KubusSearchResultKind.institution,
            id: 'i1',
            detail: 'Museum',
          ),
        ],
        <String>['PROFILES', 'INSTITUTIONS', 'Museum'],
      );
    });

    testWidgets('tapping a collection reports the collection, not an artwork',
        (tester) async {
      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = _controller(const <KubusSearchResult>[
        KubusSearchResult(
          label: 'Ljubljana fountains',
          kind: KubusSearchResultKind.collection,
          id: 'c1',
        ),
      ]);
      addTearDown(controller.dispose);

      KubusSearchResult? tapped;
      await tester.pumpWidget(_harness(
        controller: controller,
        themeProvider: themeProvider,
        onResultTap: (r) => tapped = r,
      ));
      await _type(tester, 'lj');

      tester
          .widget<ListTile>(
              find.widgetWithText(ListTile, 'Ljubljana fountains'))
          .onTap
          ?.call();
      await tester.pumpAndSettle();

      expect(tapped?.kind, KubusSearchResultKind.collection);
      expect(tapped?.collectionId, 'c1');
      expect(tapped?.artworkId, isNull);
    });

    testWidgets('long titles and long author names do not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final themeProvider = ThemeProvider();
      addTearDown(themeProvider.dispose);
      final controller = _controller(const <KubusSearchResult>[
        KubusSearchResult(
          label:
              'A very long artwork title that goes on well past a single line of a phone',
          kind: KubusSearchResultKind.artwork,
          id: 'a1',
          detail:
              'An extremely long recorded artist name, with a collective and a studio',
        ),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_harness(
        controller: controller,
        themeProvider: themeProvider,
        onResultTap: (_) {},
      ));
      await _type(tester, 'ver');

      expect(tester.takeException(), isNull);
    });
  });
}
