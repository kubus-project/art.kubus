import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/search/kubus_general_search.dart';
import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:art_kubus/widgets/search/kubus_search_controller.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('search results are clickable and outside click dismisses overlay',
      (tester) async {
    final themeProvider = ThemeProvider();
    addTearDown(themeProvider.dispose);

    final controller = KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.home,
        minChars: 1,
        debounceDuration: Duration.zero,
      ),
      searchService: _FakeSearchService(),
    );
    addTearDown(controller.dispose);

    KubusSearchResult? tapped;

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProvider,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: KubusGeneralSearch(
                    controller: controller,
                    hintText: 'Search',
                    semanticsLabel: 'test_search_input',
                  ),
                ),
                KubusSearchResultsOverlay(
                  controller: controller,
                  minCharsHint: 'min chars',
                  noResultsText: 'no results',
                  onResultTap: (result) {
                    tapped = result;
                    controller.dismissOverlay();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Let the initial route transition/overlay settle so widgets can receive
    // pointer events (Navigator uses IgnorePointer during transitions).
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    // Focus the field to ensure the controller has an active anchor link.
    await tester.tap(field);
    await tester.pump();

    // Enter a query to trigger the overlay.
    await tester.enterText(field, 'a');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsAtLeastNWidgets(1));

    // Tap a result and ensure callback fires.
    final firstTile = find.byType(ListTile).first;
    await tester.ensureVisible(firstTile);
    await tester.tap(firstTile);
    await tester.pumpAndSettle();

    expect(tapped, isNotNull);

    // Show again and ensure outside click dismisses.
    await tester.showKeyboard(field);
    await tester.enterText(field, 'ab');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsAtLeastNWidgets(1));

    // Tap outside the dropdown panel area.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(controller.state.isOverlayVisible, isFalse);
  });
}

class _FakeSearchService extends SearchService {
  @override
  Future<List<KubusSearchResult>> fetchResults({
    required SearchContextSnapshot snapshot,
    required String query,
    required KubusSearchConfig config,
  }) async {
    return <KubusSearchResult>[
      const KubusSearchResult(
        label: 'Open Home',
        kind: KubusSearchResultKind.screen,
        id: 'home',
      ),
      const KubusSearchResult(
        label: 'Open Map',
        kind: KubusSearchResultKind.screen,
        id: 'map',
      ),
    ];
  }
}
