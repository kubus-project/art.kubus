import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/utils/map_search_suggestion.dart';

class _SearchHarness extends StatelessWidget {
  const _SearchHarness({
    required this.future,
  });

  final Future<List<MapSearchSuggestion>> future;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 240,
            child: FutureBuilder<List<MapSearchSuggestion>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                final suggestions =
                    snapshot.data ?? const <MapSearchSuggestion>[];
                if (suggestions.isEmpty) {
                  return const Center(child: Text('No results found'));
                }
                return ListView.builder(
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ListTile(
                      title: Text(suggestion.label),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search with empty query renders empty state', (tester) async {
    await tester.pumpWidget(
      _SearchHarness(
        future: Future.value(const <MapSearchSuggestion>[]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No results found'), findsOneWidget);
  });

  testWidgets('search with query renders results', (tester) async {
    await tester.pumpWidget(
      _SearchHarness(
        future: Future.value(
          const <MapSearchSuggestion>[
            MapSearchSuggestion(
              label: 'Ocean Light',
              type: 'artwork',
              id: 'artwork-1',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ocean Light'), findsOneWidget);
  });
}
