import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:art_kubus/widgets/search/kubus_general_search.dart';
import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:art_kubus/widgets/search/kubus_search_controller.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _results = <KubusSearchResult>[
  KubusSearchResult(
    label: 'Mural walk',
    kind: KubusSearchResultKind.event,
    id: 'e1',
  ),
  KubusSearchResult(
    label: 'Riverside mural',
    kind: KubusSearchResultKind.artwork,
    detail: 'Ana Kovač · Ljubljana',
    id: 'a1',
  ),
  KubusSearchResult(
    label: 'Ana Kovač',
    kind: KubusSearchResultKind.profile,
    id: 'p1',
  ),
  KubusSearchResult(
    label: 'Mural at dusk',
    kind: KubusSearchResultKind.artwork,
    id: 'a2',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('groupSearchResults', () {
    test('orders groups by entity type and keeps relevance within groups', () {
      final groups = groupSearchResults(_results);

      expect(
        groups.map((g) => g.kind).toList(),
        <KubusSearchResultKind>[
          KubusSearchResultKind.artwork,
          KubusSearchResultKind.profile,
          KubusSearchResultKind.event,
        ],
      );
      expect(
        groups.first.results.map((r) => r.id).toList(),
        <String>['a1', 'a2'],
      );
    });

    test('omits empty groups', () {
      expect(groupSearchResults(const <KubusSearchResult>[]), isEmpty);
    });
  });

  Future<KubusSearchController> pumpSearch(
    WidgetTester tester, {
    required Size size,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final themeProvider = ThemeProvider();
    addTearDown(themeProvider.dispose);
    final controller = KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.home,
        minChars: 1,
        debounceDuration: Duration.zero,
      ),
      searchService: _FixtureSearchService(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProvider,
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: KubusGeneralSearch(
                      controller: controller,
                      hintText: 'Search',
                      semanticsLabel: 'search_input',
                    ),
                  ),
                ),
                KubusSearchResultsOverlay(
                  controller: controller,
                  minCharsHint: 'min chars',
                  noResultsText: 'no results',
                  onResultTap: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'mural');
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('results render under type headings with counts', (tester) async {
    await pumpSearch(tester, size: const Size(390, 844));

    expect(find.text('ARTWORKS'), findsOneWidget);
    expect(find.text('PROFILES'), findsOneWidget);
    expect(find.text('EVENTS'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(4));

    final artworks = tester.getTopLeft(find.text('ARTWORKS')).dy;
    final profiles = tester.getTopLeft(find.text('PROFILES')).dy;
    final events = tester.getTopLeft(find.text('EVENTS')).dy;
    expect(artworks, lessThan(profiles));
    expect(profiles, lessThan(events));
  });

  testWidgets('Slovenian group headings are localized', (tester) async {
    await pumpSearch(
      tester,
      size: const Size(390, 844),
      locale: const Locale('sl'),
    );
    expect(find.text('DOGODKI'), findsOneWidget);
  });

  for (final width in <double>[320, 390]) {
    testWidgets('results panel stays inside a ${width.toInt()}px screen',
        (tester) async {
      await pumpSearch(tester, size: Size(width, 700));

      final field = tester.getRect(find.byType(TextField));
      final tile = tester.getRect(find.byType(ListTile).first);
      expect(tile.right, lessThanOrEqualTo(width));
      // The panel is anchored to, and no wider than, the field row.
      expect(tile.left, greaterThanOrEqualTo(field.left - 24));
      expect(tester.takeException(), isNull);
    });
  }
}

class _FixtureSearchService extends SearchService {
  @override
  Future<List<KubusSearchResult>> fetchResults({
    required SearchContextSnapshot snapshot,
    required String query,
    required KubusSearchConfig config,
  }) async =>
      _results;
}
