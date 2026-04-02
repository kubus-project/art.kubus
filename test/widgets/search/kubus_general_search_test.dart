import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:art_kubus/widgets/search/kubus_general_search.dart';
import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:art_kubus/widgets/search/kubus_search_controller.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _SearchHarness extends StatelessWidget {
  const _SearchHarness({
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
        home: Scaffold(
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: KubusGeneralSearch(
                  controller: controller,
                  hintText: 'Search',
                  semanticsLabel: 'shared_search_input',
                ),
              ),
              KubusSearchResultsOverlay(
                controller: controller,
                minCharsHint: 'Type at least 2 characters',
                noResultsText: 'No results',
                accentColor: Colors.teal,
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

  testWidgets('result tap still fires after text field loses focus',
      (tester) async {
    final themeProvider = ThemeProvider();
    addTearDown(themeProvider.dispose);
    final controller = KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.home,
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

    KubusSearchResult? tappedResult;

    await tester.pumpWidget(
      _SearchHarness(
        controller: controller,
        themeProvider: themeProvider,
        onResultTap: (result) {
          tappedResult = result;
        },
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Ocean');
    await tester.pump();
    await tester.pump();

    expect(find.text('Ocean Light'), findsOneWidget);

    await tester.tap(find.text('Ocean Light'));
    await tester.pumpAndSettle();

    expect(tappedResult?.id, 'art-1');
  });

  testWidgets('profile results render avatar leading content', (tester) async {
    final themeProvider = ThemeProvider();
    addTearDown(themeProvider.dispose);
    final controller = KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.community,
        debounceDuration: Duration.zero,
      ),
      searchService: _FakeSearchService(
        const <KubusSearchResult>[
          KubusSearchResult(
            label: 'Ada',
            kind: KubusSearchResultKind.profile,
            id: 'wallet-123',
            data: <String, dynamic>{
              'wallet': 'wallet-123',
              'avatarUrl': 'https://example.com/avatar.png',
            },
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _SearchHarness(
        controller: controller,
        themeProvider: themeProvider,
        onResultTap: (_) {},
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    await tester.pump();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.byType(AvatarWidget), findsOneWidget);
  });
}
